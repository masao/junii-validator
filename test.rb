#!/usr/bin/env ruby
# $Id$

require 'test/unit'

require "validator.rb"

class TestJuNII2Validator < Test::Unit::TestCase
   def test_validator
      [
       "http://eprints.lib.hokudai.ac.jp/dspace-oai/request",
       "http://repository.kulib.kyoto-u.ac.jp/dspace-oai/request",
       "http://koara.lib.keio.ac.jp/xoonips/modules/xoonips/oai.php",
      ].each do |url|
         validator = JuNii2Validator.new( url )
         result = validator.validate
         result[ :error ].each do |e|
            assert( e.kind_of?( Hash ) )
            assert( e[ :error_id ] )
         end
      end
   end

   def test_validator_from
      validator = JuNii2Validator.new( "http://eprints.lib.hokudai.ac.jp/dspace-oai/request" )
      result = validator.validate( :from => ( Date.today - 30 ).to_s )
      result[ :error ].each do |e|
         assert( e.kind_of?( Hash ) )
      end
      assert( result[ :info ].grep( /\AThe size of ListRecords: (\d+)\Z/ ) )
      assert( $1.to_i > 0 )

      result = validator.validate( :from => ( Date.today - 30 ).to_s,
      				   :until =>( Date.today ).to_s )
      result[ :error ].each do |e|
         assert( e.kind_of?( Hash ) )
      end
      assert( result[ :info ].grep( /\AThe size of ListRecords: (\d+)\Z/ ) )
      assert( $1.to_i > 0 )
   end
end
