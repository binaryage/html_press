module HtmlPress
  require 'yui/compressor'
  def self.style_compressor (text)
    compressor = YUI::CssCompressor.new
    compressor.compress text
  end
end