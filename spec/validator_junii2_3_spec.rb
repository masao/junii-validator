#!/usr/bin/env ruby
# $Id$

require_relative "../validator.rb"

describe "validator.rb" do
   it "should support JuNii2 Version 3." do
      okayama_u_url = "https://ousar.lib.okayama-u.ac.jp/oai/Request"
      validator = JuNii2Validator.new( okayama_u_url )
      result = validator.validate
   end
end
