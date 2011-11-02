require 'jsonpath'

World(Rack::Test::Methods)

Given /^I accept (XML|JSON)$/ do |type|
  page.driver.header 'Accept', "application/#{type.downcase}"
end

Given /^I send (XML|JSON)$/ do |type|
  page.driver.header 'Content-Type', "application/#{type.downcase}"
end

Given /^I send and accept (XML|JSON)$/ do |type|
  step "I accept #{type}"
  step "I send #{type}"
end

When /^I authenticate as the user "([^"]*)" with the password "([^"]*)"$/ do |user, pass|
  if page.driver.respond_to?(:basic_auth)
    page.driver.basic_auth(user, pass)
  elsif page.driver.respond_to?(:basic_authorize)
    page.driver.basic_authorize(user, pass)
  elsif page.driver.respond_to?(:browser) && page.driver.browser.respond_to?(:basic_authorize)
    page.driver.browser.basic_authorize(user, pass)
  elsif page.driver.respond_to?(:authorize)
    page.driver.authorize(user, pass)
  else
    raise "Can't figure out how to log in with the current driver!"
  end
end

When /^I send a (GET|POST|PUT|DELETE) request (?:for|to) "([^"]*)"(?: with the following:)?$/ do |request_type, path, *body|
  if body.present?
    page.driver.send(request_type.downcase.to_sym, path, body.first)
  else
    page.driver.send(request_type.downcase.to_sym, path)
  end
end

Then /^show me the response$/ do
  p "Status: #{page.driver.response.status} (#{Rack::Utils::HTTP_STATUS_CODES[page.driver.response.status]})"
  b = page.driver.response.body
  b = JSON.pretty_generate(JSON.parse(b)) if page.driver.response.headers['Content-Type'].match 'json'
  print b
end

Then /^the response status should be "([^"]*)"$/ do |status|
  if status.match /\D/
    reverse= Hash[Rack::Utils::HTTP_STATUS_CODES.map{|k,v| [v.downcase,k]}]
    status = reverse[status.downcase] if reverse[status.downcase]
  end
  if page.respond_to? :should
    page.driver.response.status.should == status.to_i
  else
    assert_equal status.to_i, page.driver.response.status
  end
end

Then /^the JSON response should (not)?\s?have "([^"]*)" with the text "([^"]*)"$/ do |negative, json_path, text|
  json    = JSON.parse(page.driver.response.body)
  results = JsonPath.new(json_path).on(json).to_a.map(&:to_s)
  if page.respond_to?(:should)
    if negative.present?
      results.should_not include(text)
    else
      results.should include(text)
    end
  else
    if negative.present?
      assert !results.include?(text)
    else
      assert results.include?(text)
    end
  end
end

Then /^the XML response should have "([^"]*)" with the text "([^"]*)"$/ do |xpath, text|
  parsed_response = Nokogiri::XML(last_response.body)
  elements = parsed_response.xpath(xpath)
  if page.respond_to?(:should)
    elements.should_not be_empty, "could not find #{xpath} in:\n#{last_response.body}"
    elements.find { |e| e.text == text }.should_not be_nil, "found elements but could not find #{text} in:\n#{elements.inspect}"
  else
    assert !elements.empty?, "could not find #{xpath} in:\n#{last_response.body}"
    assert elements.find { |e| e.text == text }, "found elements but could not find #{text} in:\n#{elements.inspect}"
  end
end

Given /^I authenticate using "([^"]*)" \/ "([^"]*)"$/ do |arg1, arg2|
  step "I authenticate as the user \"#{arg1}\" with the password \"#{arg2}\""
end

Then /^what\??$/ do
  step "show me the response"
end

Then /^the JSON response should be an object with keys:?$/ do |table|
  keys = table.column_names
  json = JSON.parse(page.driver.response.body)
  keys.each do|key|
    json.should include(key)
  end
end
