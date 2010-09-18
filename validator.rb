#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# $Id$

require "net/http"
require "net/https"

require "pp"

require "rubygems"
require "libxml"

class JuNii2Validator
   JUNII2_XSD = "http://irdb.nii.ac.jp/oai/junii2.xsd"
   JUNII2_NAMESPACE = "http://irdb.nii.ac.jp/oai"
   attr_reader :baseurl
   def initialize( url )
      @baseurl = URI.parse( url )
      @xml_schema = LibXML::XML::Schema.new( JUNII2_XSD )
   end

   def validate( options = {} )
      result = {
         :warn => [],
         :error=> [],
         :info => [],
      }
      http( @baseurl ).start do |con|
         STDERR.puts @baseurl
         # Identify
         res, = con.get( "#{ @baseurl.path }?verb=Identify" )
         xml = res.body
         parser = LibXML::XML::Parser.string( xml )
         doc = parser.parse
         # p doc
         %w[ repositoryName baseURL protocolVersion  ].each do |e|
            element = doc.find( "//oai:#{ e }",
                                "oai:http://www.openarchives.org/OAI/2.0/" )
            if element.size == 1 and not element.first.content.empty?
               result[ :info ] << "#{ e }: #{ element.first.content }"
            else
               result[ :warn ] << "#{ e } is empty."
            end
         end

         # ListMetadataFormats
         junii2_ns = nil
         res, = con.get( "#{ @baseurl.path }?verb=ListMetadataFormats" )
         xml = res.body
         parser = LibXML::XML::Parser.string( xml )
         doc = parser.parse
         element = doc.find( "//oai:metadataFormat",
                             "oai:http://www.openarchives.org/OAI/2.0/" )
         if element.empty?
            result[ :error ] << {
               :message => "No metadataFormat supported.",
               :error_id => :no_metadataFormat,
            }
         else
            supported_formats = []
            element.each do |e|
               prefix = e.find( "./oai:metadataPrefix",
                                "oai:http://www.openarchives.org/OAI/2.0/" )[0].content
               supported_formats << prefix
               if prefix == "junii2"
                  junii2_ns = e.find( "./oai:metadataNamespace",
                                      "oai:http://www.openarchives.org/OAI/2.0/" )
                  if junii2_ns.nil? or junii2_ns.empty?
                     result[ :error ] << {
                        :message => "junii2 metadataPrefix does not have metadataNamespace.",
                        :error_id => :no_metadataNamespace,
                        :link => :ListMetadataFormats,
                     }
                     junii2_ns = JUNII2_NAMESPACE
                  else
                     junii2_ns = junii2_ns[0].content
                  end
                  if not junii2_ns == JUNII2_NAMESPACE
                     result[ :error ] << {
                        :message => "This JuNii2 namespace ('#{ junii2_ns }') is different with the latest one ('#{ JUNII2_NAMESPACE }').",
                        :error_id => :junii2_namespace,
			:link => :ListMetadataFormats,
                     }
                     # Fallback to old namespace.
                     xsd_uri = URI.parse( JUNII2_XSD )
                     res, = http( xsd_uri ).get( xsd_uri.request_uri )
                     xml = res.body.gsub( /#{ Regexp.escape( JUNII2_NAMESPACE ) }/sm ){|m| junii2_ns }
                     parser = LibXML::XML::Parser.string( xml )
                     #parser = LibXML::XML::Parser.file( "junii2.xsd" )
                     doc = parser.parse
                     #doc.root.attributes[ 'targetNamespace' ] = junii2_ns
                     #doc.root.attributes[ 'xmlns' ] = junii2_ns
                     @xml_schema = LibXML::XML::Schema.document( doc )
                  end
               end
            end
            result[ :info ] << "Supported metadataFormat: " + supported_formats.join( ", " )
            if not supported_formats.include?( "junii2" )
               result[ :error ] << {
                  :message => "junii2 metadata format is not supported.",
                  :error_id => :junii2_unsupported,
               }
            end
         end

         # ListRecords
         params = "&metadataPrefix=junii2"
         options.each do |k, v|
            case k
            when :from, :until, :set
               params << "&#{ k }=#{ URI.escape( v ) }"
            end
         end
	 if options[ :resumptionToken ]
	    params = "&resumptionToken=#{ URI.escape( options[ :resumptionToken ] ) }"
	 end
         res, = con.get( "#{ @baseurl.path }?verb=ListRecords&#{ params }" )
         if not res.code == "200"
            result[ :error ] << {
               :error_id => :not_success_http,
               :error_message => "The server does not return success code: #{ res.code }",
               :link => :ListRecords,
            }
            return result
         end
         xml = res.body
         doc = nil
         begin
            parser = LibXML::XML::Parser.string( xml )
            doc = parser.parse
         rescue LibXML::XML::Error => err
            result[ :error ] << {
               :error_id => :parse_error,
               :message => "ListRecords returned malformed XML data.",
               :link => :ListRecords,
            }
            return result
         end
         resumption_token = doc.find( "//oai:resumptionToken",
                                      "oai:http://www.openarchives.org/OAI/2.0/" )
         if not resumption_token.nil? and not resumption_token.empty?
            result[ :next_token ] = resumption_token.first.content
         end
         element = doc.find( "//oai:metadata",
                             "oai:http://www.openarchives.org/OAI/2.0/" )
         result[ :info ] << "The size of ListRecords: #{ element.size }"
	 if element.empty?
            result[ :warn ] << {
	       :message => "ListRecords returned zero records.",
	       :link => :ListRecords,
	       :error_id => :zero_listrecords,
	    }
	 end
         element.each do |e|
            # metadata = e.inner_xml.strip
            # metadata = LibXML::XML::Document.string( metadata )
            metadata = LibXML::XML::Document.new
            metadata.root = e.child.copy( true )
            if metadata.root.nil? or e.child.empty?	# adhoc for XooNips.
               metadata.root = e.child.next.copy( true )
            end
            if metadata.root.namespaces.namespace.nil?
               result[ :error ] << {
                  :message => "junii2 namespace is not specified.",
                  :error_id => :no_junii2_namespace,
		  :link => :ListRecords,
               }
               junii2_ns = LibXML::XML::Namespace.new( metadata.root, nil, JUNII2_NAMESPACE )
               metadata.root.namespaces.namespace =junii2_ns
               metadata = LibXML::XML::Document.string( metadata.to_s )
            end
            begin
               metadata.validate_schema( @xml_schema )
            rescue LibXML::XML::Error => err
               # err.message
               error_id =
                  case err.message
                  when /No matching global declaration available for the validation root/
                     :wrong_root_element
                  when /This element is not expected. Expected is one of \( .* \)/
                     :sequence
                  when /is not a valid value of the atomic type \'\{.*\}issnType\'/
                     :issnType
                  when /is not a valid value of the atomic type \'\{.*\}numberType\'/
                     :numberType
                  when /is not a valid value of the union type \'\{.*\}languageType\'/
                     :languageType
                  when /is not a valid value of the atomic type \'xs:anyURI\'/
                     :anyURL
                  else
                     nil
                  end
               result[ :error ] << {
                  :message => "XML Schema error: #{ err.message }",
                  :error_id => error_id,
                  :identifier => e.parent.find( "./oai:header/oai:identifier",
                                                "oai:http://www.openarchives.org/OAI/2.0/" )[0].content
               }
            end

            # junii2 guideline version 1: creator
            creators = metadata.find( "//junii2:creator", "junii2:#{ junii2_ns }" )
            creators.each do |creator|
               if creators.size > 1 and creator.content =~ /\A[ア-ン　，,\s]+Z/
                  result[ :warn ] << {
                     :error_id => :katakana_creator,
                     :message => "Creator '#{ creator.content }' contains only Katakana characters.",
                     :identifier => e.parent.find( "./oai:header/oai:identifier",
                                                   "oai:http://www.openarchives.org/OAI/2.0/" )[0].content,
                  }
               end
            end
         end
      end
      result
   end

   private
   def http( uri )
      http_proxy = ENV[ "http_proxy" ]
      proxy, proxy_port = nil
      if http_proxy
         proxy_uri = URI.parse( http_proxy )
         proxy = proxy_uri.host
         proxy_port = proxy_uri.port
      end
      http = Net::HTTP.Proxy( proxy, proxy_port ).new( uri.host, uri.port )
      http.use_ssl = true if uri.scheme == "https"      
      http
   end
end

if $0 == __FILE__
   ARGV.each do |url|
      validator = JuNii2Validator.new( url )
      result = validator.validate
      [ :info, :error, :warn ].each do |k|
         puts "Total #{ result[ k ].size } #{ k }:"
         pp result[ k ]
      end
      if result[ :next_token ]
         puts "resumptionToken: #{ result[ :next_token ].inspect }"
      end
   end
end
