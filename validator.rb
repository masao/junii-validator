#!/usr/bin/env ruby
# $Id$

require "net/http"
require "net/https"

require "pp"

require "rubygems"
require "libxml"

class JuNii2Validator
   JUNII2_XSD = "http://irdb.nii.ac.jp/oai/junii2.xsd"
   attr_reader :baseurl
   def initialize( url )
      @baseurl = URI.parse( url )

      xsd_uri = URI.parse( JUNII2_XSD )
      res, = Net::HTTP.new( xsd_uri.host, xsd_uri.port ).get( xsd_uri.path )
      parser = LibXML::XML::Parser.string( res.body )
      @xml_schema = LibXML::XML::Schema.document( parser.parse )
   end

   def validate
      result = {
         :warn => [],
         :error=> [],
         :info => [],
      }
      http = Net::HTTP.new( @baseurl.host, @baseurl.port )
      http.start do |con|
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
         res, = con.get( "#{ @baseurl.path }?verb=ListMetadataFormats" )
         xml = res.body
         parser = LibXML::XML::Parser.string( xml )
         doc = parser.parse
         element = doc.find( "//oai:metadataFormat",
                             "oai:http://www.openarchives.org/OAI/2.0/" )
         if element.empty?
            result[ :error ] << "Zero metadataFormat supported."
         else
            supported_formats = element.map do |e|
               e.find( "./oai:metadataPrefix",
                       "oai:http://www.openarchives.org/OAI/2.0/" )[0].content
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
         result[ :warn ] << "ListRecords returned zero records." if element.empty?
         element.each do |e|
            metadata = e.child
            doc = LibXML::XML::Document.string( metadata.to_s )
            begin
               doc.validate_schema( @xml_schema )
            rescue LibXML::XML::Error => err
               # err.message
               result[ :error ] << "XML Schema error: #{ err.message }}" +
                  "\n\tfor http://hdl.handle.net/2115/328"
            end
         end
      end
      result
   end
end

if $0 == __FILE__
   ARGV.each do |url|
      validator = JuNii2Validator.new( url )
      result = validator.validate
      pp result
   end
end
