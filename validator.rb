#!/usr/bin/env ruby
# $Id$

require "net/http"
require "net/https"

require "pp"

require "rubygems"
require "libxml"

class JuNii2Validator
   attr_reader :baseurl
   def initialize( url )
      @baseurl = URI.parse( url )
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
