require 'mechanize'

@log = Logger.new(STDOUT)
@log.level = Logger::INFO

@agent = Mechanize.new { |a|
  a.user_agent_alias = 'Windows IE 10'
  a.user_agent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.75 Safari/537.36'
  a.log = @log
}

date = "2017-04-06"
credentials = YAML.load_file "credentials.yml"

page = @agent.get "https://select-a-spot.com/bart/"
page = page.form_with(:id => "site-login") do |login|
  login.username = credentials[:username]
  login.password = credentials[:password]
end.submit

page = page.link_with(:href => "/bart/reservations/facilities/?type=daily").click

page = page.form_with(:action => "/bart/reservations/date/") do |form|
  form.radiobutton_with(:id => "type_id_40").check
end.submit

# http://mechanize.rubyforge.org/Mechanize/Page.html
page = page.form_with(:action => "/bart/reservations/date/") do |form|
  form.start_date = date
  form.end_date = date
end.submit

if (page.body =~ /Reservations cannot be made more than two months in advance/)
  @log.info "Too far out"
else
  if (page.body =~ /This facility has no availability for the date range you selected. Please choose from one of the following facilities which do have availability,/)
    page = page.form_with(:action => "/bart/reservations/date/") do |form|
      form.radiobutton_with(:id => "type_id_37").check
    end.submit
  end

  page = page.form_with(:action => "/bart/reservations/reserve/").submit

  page = page.link_with(:href => /confirm/).click

  page = page.form_with(:id => "complete_form") do |form|
    form.checkbox_with(:name => "conditions").check
  end.submit

  # page = "/bart/reservations/print_permit/?id=#{id}&date=0"
  # receive {successs:true}
  # page = "/bart/reservations/permit_pdf/?id=#{id}"
  # receive PDF

  p page.body
end
