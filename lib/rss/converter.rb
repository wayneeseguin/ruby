require "rss/utils"

module RSS

	class Converter
		
		include Utils

		def initialize(to_enc, from_enc=nil)
			to_enc = to_enc.downcase.gsub(/-/, '_')
			from_enc ||= 'utf-8'
			from_enc = from_enc.downcase.gsub(/-/, '_')
			if to_enc == from_enc
				def_same_enc()
			else
				if respond_to?("def_to_#{to_enc}_from_#{from_enc}")
					send("def_to_#{to_enc}_from_#{from_enc}")
				else
					def_else_enc(to_enc, from_enc)
				end
			end
		end

		def convert(value)
			value
		end

		def def_convert(depth=0)
			instance_eval(<<-EOC, *get_file_and_line_from_caller(depth))
			def convert(value)
				if value.kind_of?(String)
					#{yield('value')}
				else
					value
				end
			end
			EOC
		end

		def def_iconv_convert(to_enc, from_enc, depth=0)
			begin
				require "iconv"
				def_convert(depth+1) do |value|
					<<-EOC
					@iconv ||= Iconv.new("#{to_enc}", "#{from_enc}")
					begin
						@iconv.iconv(#{value})
					rescue Iconv::Failure
						raise ConversionError.new(#{value}, "#{to_enc}", "#{from_enc}")
					end
					EOC
				end
			rescue LoadError, ArgumentError, SystemCallError
				raise UnknownConversionMethodError.new(to_enc, from_enc)
			end
		end
		
		def def_else_enc(to_enc, from_enc)
			raise UnknownConversionMethodError.new(to_enc, from_enc)
		end
		
		def def_same_enc()
			def_convert do |value|
				value
			end
		end

		def def_uconv_convert_if_can(meth, to_enc, from_enc)
			begin
				require "uconv"
				def_convert(1) do |value|
					<<-EOC
					begin
						Uconv.#{meth}(#{value})
					rescue Uconv::Error
						raise ConversionError.new(#{value}, "#{to_enc}", "#{from_enc}")
					end
					EOC
				end
			rescue LoadError
				def_iconv_convert(to_enc, from_enc, 1)
			end
		end

		def def_to_euc_jp_from_utf_8
			def_uconv_convert_if_can('u8toeuc', 'EUC-JP', 'UTF-8')
		end
		
		def def_to_utf_8_from_euc_jp
			def_uconv_convert_if_can('euctou8', 'UTF-8', 'EUC-JP')
		end
		
		def def_to_shift_jis_from_utf_8
			def_uconv_convert_if_can('u8tosjis', 'Shift_JIS', 'UTF-8')
		end
		
		def def_to_utf_8_from_shift_jis
			def_uconv_convert_if_can('sjistou8', 'UTF-8', 'Shift_JIS')
		end
		
		def def_to_euc_jp_from_shift_jis
			require "nkf"
			def_convert do |value|
				"NKF.nkf('-Se', #{value})"
			end
		end
		
		def def_to_shift_jis_from_euc_jp
			require "nkf"
			def_convert do |value|
				"NKF.nkf('-Es', #{value})"
			end
		end
		
		def def_to_euc_jp_from_iso_2022_jp
			require "nkf"
			def_convert do |value|
				"NKF.nkf('-Je', #{value})"
			end
		end
		
		def def_to_iso_2022_jp_from_euc_jp
			require "nkf"
			def_convert do |value|
				"NKF.nkf('-Ej', #{value})"
			end
		end

		def def_to_utf_8_from_iso_8859_1
			def_convert do |value|
				"#{value}.unpack('C*').pack('U*')"
			end
		end
		
		def def_to_iso_8859_1_from_utf_8
			def_convert do |value|
				<<-EOC
				array_utf8 = #{value}.unpack('U*')
				array_enc = []
				array_utf8.each do |num|
					if num <= 0xFF
						array_enc << num
					else
						array_enc.concat "&\#\#{num};".unpack('C*')
					end
				end
				array_enc.pack('C*')
				EOC
			end
		end
		
	end
	
end
