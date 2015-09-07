#!/usr/bin/env ruby
# $Id$

require_relative "../validator.rb"

describe "validator.rb" do
   TEST_SITE = [
                "http://eprints.lib.hokudai.ac.jp/dspace-oai/request",
                "http://repository.kulib.kyoto-u.ac.jp/dspace-oai/request",
                "http://koara.lib.keio.ac.jp/xoonips/modules/xoonips/oai.php",
                "http://petit.lib.yamaguchi-u.ac.jp/infolib/oai_repository/repository",
                "http://ousar.lib.okayama-u.ac.jp/oai/Request",
               ]
   it "should validate several IR sites without any errors." do
      TEST_SITE.each do |url|
         validator = JuNii2Validator.new( url )
         result = validator.validate
         result[ :error ].each do |e|
            e.should be_a_kind_of( Hash )
            e.should have_key( :error_id )
         end
         result.should has_key( :next_token )
      end
   end

   it "should accept 'from' parameter." do
      validator = JuNii2Validator.new( TEST_SITE.first )
      result = validator.validate( :from => ( Date.today - 30 ).to_s )
      result[ :error ].each do |e|
         e.should be_a_kind_of( Hash )
      end
      STDERR.puts result[ :info ].inspect
      result[ :info ].grep( /\AThe size of ListRecords: (\d+)\Z/ ).should_not be_empty
      $1.to_i.should > 0

      result = validator.validate( :from => ( Date.today - 30 ).to_s,
      				   :until =>( Date.today ).to_s )
      result[ :error ].each do |e|
         e.should be_a_kind_of( Hash )
      end
      result[ :info ].grep( /\AThe size of ListRecords: (\d+)\Z/ ).should_not be_empty
      $1.to_i.should > 0
   end
end
