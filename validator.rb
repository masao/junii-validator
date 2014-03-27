#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# $Id$

require "date"
require "net/http"
require "net/https"
require "optparse"

require "pp"

require "rubygems"
require "libxml"

class URI::HTTP
   def merge_request_uri( query_s )
      if self.query
         request_uri + "&#{ query_s }"
      else
      	 path + "?#{ query_s }"
      end
   end
end

class JuNii2Validator
   #JUNII2_XSD = "http://irdb.nii.ac.jp/oai/junii2.xsd"
   #JUNII2_XSD = "http://irdb.nii.ac.jp/oai/junii2-3_0.xsd"
   JUNII2_XSD = "http://irdb.nii.ac.jp/oai/junii2-3-1.xsd"
   JUNII2_NAMESPACE = "http://irdb.nii.ac.jp/oai"
   NIIsubject = %w[
    全般
    人文科学
    哲学・倫理学
    宗教
    心理学
    美学・芸術学
    歴史学
    考古学
    民族学
    文化人類学・民俗学
    地理学・地誌
    言語学
    文学
    社会科学
    政治・行政
    法律・法律学
    経済学
    ビジネス・経営・産業
    社会・文化
    教育・教育学
    軍事
    運輸・交通
    環境学
    メディア・コミュニケーション
    厚生・福祉
    芸術
    美学・芸術学
    文学
    建築学
    美術
    音楽
    演劇
    映画・テレビ
    諸芸
    漫画
    自然科学
    数学
    物理学
    化学
    天文学
    地球惑星科学
    生物学
    地理学・地誌
    自然人類学
    環境学
    生命科学
    医学
    基礎医学
    社会医学
    内科系臨床医学
    外科系臨床医学
    歯学
    薬学
    看護学
    心理学
    獣医学
    生物学
    ゲノム科学
    農学
    農学
    農芸化学
    林学
    水産学
    農業工学
    畜産学
    獣医学
    環境学
    生物学
    工学
    基礎工学・応用物理学
    機械工学
    電気電子工学
    土木工学
    建築学
    材料工学
    プロセス工学・化学工学
    航空工学
    船舶・海洋工学
    エネルギー工学
    ナノテクノロジー
    情報学
    環境学
    情報・メディア・コミュニケーション
    情報学
    メディア・コミュニケーション
    厚生・福祉
    家政学・生活科学
    習俗
    趣味・娯楽
    生活・家庭
    健康・スポーツ科学
   ]
   NIIspatial = %w[
   日本
   北海道
   東北
   青森 岩手 宮城 秋田 山形 福島
   関東
   茨城 栃木 群馬 埼玉 千葉 東京 神奈川
   北陸
   新潟 富山 石川 福井
   中部
   山梨 長野 岐阜 静岡 愛知
   三重
   近畿
   滋賀 京都 大阪 兵庫 奈良 和歌山
   中国
   鳥取 島根 岡山 広島 山口
   四国
   徳島 香川 愛媛 高知
   九州
   福岡 佐賀 長崎 熊本 大分 宮崎 鹿児島
   沖縄
   海外
   アジア
   東アジア
   東南アジア
   南アジア
   中東地域
   朝鮮半島
   環太平洋地域
   中華人民共和国
   韓国
   タイ
   インド
   インドネシア
   ベトナム
   モンゴル
   ネパール
   フィリピン
   台湾
   バングラデシュ
   ミャンマー
   マレーシア
   シンガポール
   イラン
   シリア
   ヨーロッパ
   西欧
   東欧
   イギリス
   ドイツ
   フランス
   ロシア
   ギリシャ
   イタリア
   スウェーデン
   スペイン
   ポーランド
   アフリカ
   エジプト
   環太平洋地域
   北米
   アメリカ合衆国
   環太平洋地域
   ブラジル
   中南米
   メキシコ
   オセアニア
   環太平洋地域
   オーストラリア
   南極・北極
   海洋・宇宙
   ]

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
         res, = con.get( @baseurl.merge_request_uri( "verb=Identify" ) )
	 #res.value
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
         res, = con.get( @baseurl.merge_request_uri( "verb=ListMetadataFormats" ) )
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
         res, = con.get( @baseurl.merge_request_uri( "verb=ListRecords&#{ params }" ) )
         if not res.code == "200"
            result[ :error ] << {
               :error_id => :not_success_http,
               :message => "The server does not return success code: #{ res.code }",
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
                  when /This element is not expected. Expected is (one of )?\( .* \)/
                     :sequence
                  when /is not a valid value of the atomic type \'\{.*\}issnType\'/
                     :issnType
                  when /is not a valid value of the atomic type \'\{.*\}numberType\'/
                     :numberType
                  when /is not a valid value of the union type \'\{.*\}languageType\'/
                     :languageType
                  when /is not a valid value of the atomic type \'xs:anyURI\'/
                     :anyURI
                  when /is not a valid value of the atomic type \'\{.*?\}:versionType\'/
                     :versionType
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

            # junii2 guideline version 1.0: creator
            creators = metadata.find( "//junii2:creator", "junii2:#{ junii2_ns }" )
            creators.each_with_index do |creator, idx|
               if creators.size > 1 and idx > 0 and creator.content =~ /\A[ア-ン　，,\s]+\Z/
                  result[ :warn ] << {
                     :error_id => :katakana_creator,
                     :message => "Creator '#{ creator.content }' contains only Katakana characters.",
                     :identifier => e.parent.find( "./oai:header/oai:identifier",
                                                   "oai:http://www.openarchives.org/OAI/2.0/" )[0].content,
                  }
               end
               if not creator.content =~ /, / and creator.content.size < 50
                  result[ :warn ] << {
                     :error_id => :no_comma_creator,
                     :message => "Creator '#{ creator.content }' does not contain any separators between family and given name.",
                     :identifier => e.parent.find( "./oai:header/oai:identifier",
                                                   "oai:http://www.openarchives.org/OAI/2.0/" )[0].content,
                  }
               end
            end

	    # junii2 guideline version 1.0: NIIsubject
	    elem = metadata.find( "//junii2:NIIsubject", "junii2:#{ junii2_ns }" )
	    elem.each do |s|
	       if not NIIsubject.include?( s.content )
	          result[ :error ] << {
		     :error_id => :NIIsubject,
		     :message => "Element 'NIIsubject' contains values not defined in the vocabrary: '#{ s.content }'",
		     :identifier => e.parent.find( "./oai:header/oai:identifier",
		                                                        "oai:http://www.openarchives.org/OAI/2.0/" )[0].content,
		  }
	       end
	    end
            # junii2 guideline version 1.0: subjectType
            %w[ NDC NDLC DDC LCC UDC ].each do |subject|
               elem = metadata.find( "//junii2:#{ subject }", "junii2:#{ junii2_ns }" )
               elem.each do |s|
                  if not s.content =~ /\A[\w\.]+\Z/
                     result[ :warn ] << {
                        :error_id => :subjectType,
                        :message => "Element '#{ subject }' contains characters other than numerics: '#{ s.content }'",
                        :identifier => e.parent.find( "./oai:header/oai:identifier",
                                                      "oai:http://www.openarchives.org/OAI/2.0/" )[0].content,
                     }
                  end
               end
            end

            # junii2 guideline version 1.0: format
            elem = metadata.find( "//junii2:format", "junii2:#{ junii2_ns }" )
            elem.each do |s|
               format = s.content
               if not s.content =~ /\A(application|audio|image|message|text|model|multipart|text|video|example)\/[\w\.\+\-]+\Z/
                  result[ :warn ] << {
                     :error_id => :formatType,
                     :message => "Element 'format' ('#{ format }') must be internet media type.",
                     :identifier => e.parent.find( "./oai:header/oai:identifier",
                                                   "oai:http://www.openarchives.org/OAI/2.0/" )[0].content,
		  }
	       end
            end

            # junii2 guideline version 3.0: grantid
            elem = metadata.find( "//junii2:grantid", "junii2:#{ junii2_ns }" )
            if not elem.empty?
               niitype_e = metadata.find( "//junii2:NIItype", "junii2:#{ junii2_ns }" )
               niitype = niitype_e.first.content
               if niitype != "Thesis or Dissertation"
                  result[ :error ] << {
                     :error_id => niitypeThesis,
                     :message => "Element 'NIItype' ('#{ niitype }') should be 'Thesis or Dissertation' when ETD is deposited.",
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
      http.open_timeout = 30
      http.read_timeout = 30
      http
   end
end

if $0 == __FILE__
   options = {
      :max => 20
   }
   opt = OptionParser.new
   opt.on( '--max VAL'   ){|v| options[ :max ] = v }
   opt.on( '--from VAL'  ){|v| options[ :from ] = v }
   opt.on( '--until VAL' ){|v| options[ :until ] = v }
   opt.parse!( ARGV )
   ARGV.each do |url|
      validator = JuNii2Validator.new( url )
      result = validator.validate( options )
      [ :info, :error, :warn ].each do |k|
         puts "Total #{ result[ k ].size } #{ k }:"
         pp result[ k ]
      end
      if result[ :next_token ]
         puts "resumptionToken: #{ result[ :next_token ].inspect }"
      end
   end
end
