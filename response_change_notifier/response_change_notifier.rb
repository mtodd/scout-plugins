require 'net/http'
require 'net/https'
require 'uri'

class ResponseChangeNotifier < Scout::Plugin
  include Net
  
  TIMEOUT_LENGTH = 50 # seconds
  
  def build_report
    url = option(:url).to_s.strip
    
    return error("A url wasn't provided.") if url.empty?
    
    url = "http://#{url}" unless url =~ %r{\Ahttps?://}
    
    response = http_response(url)
    
    case response
    when HTTPOK, HTTPFound
      if response.body != memory(:last_response)
        alert("The response from URL [#{url}] has changed", unindent(<<-EOF))
          URL: #{url}
          
          Code: #{response.code}
          Status: #{response.class.to_s[/^Net::HTTP(.*)$/, 1]}
          Message: #{response.message}
          
          Previous Response:
          #{memory(:last_response).gsub('<', '&lt;').gsub('>', '&gt;')}
          
          Current Response:
          #{response.body.gsub('<', '&lt;').gsub('>', '&gt;')}
        EOF
      end
    end
    
    remember(:last_response => response.body)
  rescue Exception => e
    error("Error querying URL [#{url}]",
          "#{e.message}<br><br>#{e.backtrace.join('<br>')}")
    
    remember(:last_response => memory(:last_response)) # remember last response
  end
  
  # returns the http response (string) from a url
  def http_response(url)
    uri = URI.parse(url)
    
    response = nil
    retry_url_trailing_slash = true
    retry_url_execution_expired = true
    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = url =~ %r{\Ahttps://}
      http.start do |http|
        http.open_timeout = TIMEOUT_LENGTH
        req = Net::HTTP::Get.new((uri.path != '' ? uri.path : '/' ) + (uri.query ? ('?' + uri.query) : ''))
        if uri.user && uri.password
          req.basic_auth uri.user, uri.password
        end
        response = http.request(req)
      end
    rescue Exception => e
      # forgot the trailing slash...add and retry
      if e.message == "HTTP request path is empty" and retry_url_trailing_slash
        url += '/'
        uri = URI.parse(url)
        h = Net::HTTP.new(uri.host)
        retry_url_trailing_slash = false
        retry
        
      elsif e.message =~ /execution expired/ and retry_url_execution_expired
        retry_url_execution_expired = false
        retry
        
      else
        raise
      end
    end
    
    return response
  end
  
  def unindent(string)
    indentation = string[/\A\s*/]
    string.strip.gsub(/^#{indentation}/, "")
  end
end
