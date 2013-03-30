#!/usr/local/bin/ruby
# $Id$

require "cgi"
require "erb"
require "date"

require "validator.rb"

begin
   @cgi = CGI.new
   case @cgi.host
   when "kagaku.nims.go.jp"
      ENV[ 'http_proxy' ] = 'http://wwwout.nims.go.jp:8888'
   end
   HELP_URL = "http://drf.lib.hokudai.ac.jp/drf/index.php?tech%2Fnote%2Fgeneral%2FOAI-PMH%20validator"
   url = @cgi.params[ "url" ][0]
   options = {}
   [ :from, :until, :set, :resumptionToken ].each do |k|
      next if @cgi.params[ k.to_s ].empty? or @cgi.params[ k.to_s ][0].strip.empty?
      options[ k ] = @cgi.params[ k.to_s ][0]
   end
   data = nil
   if not url.nil? and not url.empty? and not url == "http://"
      validator = JuNii2Validator.new( url )
      data = validator.validate( options )
   end

   print @cgi.header( "text/html" )

   include ERB::Util
   fname = "validator.rhtml"
   rhtml = open( fname ){|io| io.read }
   print ERB::new( rhtml, $SAFE, "<>" ).result( binding )
rescue Exception
   if @cgi then
      print @cgi.header( 'status' => CGI::HTTP_STATUS['SERVER_ERROR'], 'type' => 'text/html' )
   else
      print "Status: 500 Internal Server Error\n"
      print "Content-Type: text/html\n\n"
   end
   puts "<h1>500 Internal Server Error</h1>"
   puts "<pre>"
   puts CGI::escapeHTML( "#{$!} (#{$!.class})" )
   puts ""
   puts CGI::escapeHTML( $@.join( "\n" ) )
   puts "</pre>"
   puts "<div>#{' ' * 500}</div>"
end