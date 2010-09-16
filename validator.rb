#!/usr/bin/env ruby
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

   def validate
      result = {
         :warn => [],
         :error=> [],
         :info => [],
      }
      http( @baseurl ).start do |con|
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
            result[ :error ] << "Zero metadataFormat supported."
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
                        :help_error => :no_metadataNamespace,
                        :link => :ListMetadataFormats,
                     }
                     junii2_ns = JUNII2_NAMESPACE
                  else
                     junii2_ns = junii2_ns[0].content
                  end
                  if not junii2_ns == JUNII2_NAMESPACE
                     result[ :error ] << {
                        :message => "This JuNii2 namespace ('#{ junii2_ns }') is different with the latest one ('#{ JUNII2_NAMESPACE }').",
                        :help_error => :junii2_namespace,
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
               result[ :error ] << "junii2 metadata format is not supported."
            end
         end

         # ListRecords
         res, = con.get( "#{ @baseurl.path }?verb=ListRecords&metadataPrefix=junii2" )
         xml = res.body
         parser = LibXML::XML::Parser.string( xml )
         doc = parser.parse
         element = doc.find( "//oai:metadata",
                             "oai:http://www.openarchives.org/OAI/2.0/" )
         result[ :info ] << "The size of ListRecords: #{ element.size }"
         result[ :warn ] << "ListRecords returned zero records." if element.empty?
         element.each do |e|
            # metadata = e.find("./metadata")[0]
            # next if metadata.nil?
            # STDERR.puts metadata.first.class
            metadata = e.inner_xml.strip
            # puts metadata
            doc = LibXML::XML::Document.string( metadata )
            begin
               doc.validate_schema( @xml_schema )
            rescue LibXML::XML::Error => err
               # err.message
               error_help =
                  case err.message
                  when /No matching global declaration available for the validation root/
                     :wrong_root_element
                  when /This element is not expected. Expected is one of \( .* \)/
                     :sequence
                  when /is not a valid value of the atomic type \'\{.*\}numberType\'/
                     :numberType
                  when /is not a valid value of the atomic type \'xs:anyURI\'/
                     :anyURL
                  else
                     nil
                  end
               result[ :error ] << {
                  :message => "XML Schema error: #{ err.message }",
                  :error_help => error_help,
                  :identifier => e.parent.find( "./oai:header/oai:identifier",
                                                "oai:http://www.openarchives.org/OAI/2.0/" )[0].content
               }
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
      result.keys.each do |k|
         puts "Total #{ result[ k ].size } #{ k }:"
         pp result[ k ]
      end
   end
end
