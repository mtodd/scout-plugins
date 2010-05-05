require File.dirname(__FILE__)+"/../test_helper"
require File.dirname(__FILE__)+"/response_change_notifier"

class ResponseChangeNotifierTest < Test::Unit::TestCase
  
  def setup
    @url = "http://google.com"
    @first_response   = "Foo"
    @second_response  = "Bar"
    
    @plugin = ResponseChangeNotifier.new(nil, {:last_response => @first_response}, {:url => @url})
  end
  
  def test_no_alert_is_sent_when_the_response_stays_the_same
    FakeWeb.register_uri(:get, @url, :body => @first_response)
    result = @plugin.run
    assert_equal @first_response, result[:memory][:last_response]
    assert result[:alerts].empty?
  end
  
  def test_an_alert_is_sent_when_the_response_changes
    FakeWeb.register_uri(:get, @url, :body => @second_response)
    result = @plugin.run
    assert_equal @second_response, result[:memory][:last_response]
    assert_match /changed/, result[:alerts].first[:subject]
    assert_match /#{@first_response}/,  result[:alerts].first[:body]
    assert_match /#{@second_response}/, result[:alerts].first[:body]
  end
  
  def test_exception
    FakeWeb.register_uri(:get, @url, :exception => Net::HTTPError)
    result = @plugin.run
    assert_equal @first_response, result[:memory][:last_response]
    assert_match /error/i, result[:errors].first[:subject]
  end
  
end
