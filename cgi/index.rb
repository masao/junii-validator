#!/usr/local/bin/ruby
# $Id$

require "cgi"
require "erb"
require "validator.rb"

begin
   @cgi = CGI.new
   url = @cgi.params[ "url" ][0]
   data = nil
   if not url.nil? and not url.empty? and not url == "http://"
      validator = JuNii2Validator.new( url )
      data = validator.validate
   end

   include ERB::Util
   fname = "validator.rhtml"
   rhtml = open( fname ){|io| io.read }
   print @cgi.header( "text/html" )
   print ERB::new( rhtml, $SAFE, "<>" ).result( binding )
rescue Exception
   if @cgi then
      print @cgi.header( 'status' => CGI::HTTP_STATUS['SERVER_ERROR'], 'type' => 'text/
html' )
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
