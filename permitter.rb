#!/usr/bin/env ruby

require 'mechanize'
require 'date'
require 'thor'
require 'json'


LOGFILE = File.join(Dir.home, '.permitter.log')
CREDENTIALS_PATH = "credentials.yml"


class Permitter < Thor
  no_commands {
    def redirect_output
      unless LOGFILE == 'STDOUT'
        logfile = File.expand_path(LOGFILE)
        FileUtils.mkdir_p(File.dirname(logfile), :mode => 0755)
        FileUtils.touch logfile
        File.chmod 0644, logfile
        $stdout.reopen logfile, 'a'
      end
      $stderr.reopen $stdout
      $stdout.sync = $stderr.sync = true
    end

    def setup_logger
      redirect_output if options[:log]

      $logger = Logger.new STDOUT
      $logger.level = options[:verbose] ? Logger::DEBUG : Logger::INFO
      $logger.info 'starting'
    end

    def get_reservation agent, date
      reservation = {}
      page = agent.get "https://www.select-a-spot.com/bart/users/reservations/"
      doc = page.parser
      doc.xpath("//table").each { |table|
        table.xpath("tr").each { |tr|
          td = tr.xpath("td")
          reservation[td[0].text] = td[1].text
        }
        break if date.to_s == Date.parse(reservation["From:"]).to_s
      }
      if date.to_s == Date.parse(reservation["From:"]).to_s
        return reservation
      else
        $logger.error "couldn't find permit"
        return nil
      end
    end


    def download_permit agent, permit_id
      page = agent.get "/bart/reservations/print_permit/?id=#{permit_id}&date=0"
      result = JSON.parse page.body
      if result["success"]
        page = agent.get "/bart/reservations/permit_pdf/?id=#{permit_id}"
        filename = page.header["content-disposition"][/filename=(.*)/, 1]
        File.open(File.join(ENV['HOME'], 'Dropbox/workspace/@print', filename), "wb") do |file|
          file.write page.body
        end
      end
    end

    def skip? skips, date
      return false unless skips
      skips.each do |skip|
        return true if date >= skip[:from] && date <= skip[:to]
      end
      return false
    end
  }

  class_option :log,     :type => :boolean, :default => true, :desc => "log output to ~/.permitter.log"
  class_option :verbose, :type => :boolean, :aliases => "-v", :desc => "increase verbosity"

  desc "get", "get next available permit"
  def get
    setup_logger

    begin
      @agent = Mechanize.new { |a|
        a.user_agent_alias = 'Windows IE 10'
        a.user_agent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.75 Safari/537.36'
        a.log = $logger if options[:verbose]
      }


      date = YAML.load_file "date.yml"
      while date[:current].saturday? || date[:current].sunday? || skip?(date[:skips], date[:current])
        date[:current] = date[:current].succ
      end
      target = date[:current]

      $logger.info "(1/6) logging in"
      page = @agent.get "https://www.select-a-spot.com/bart/"
      credentials = YAML.load_file CREDENTIALS_PATH
      page = page.form_with(:id => "site-login") do |login|
        login.username = credentials[:username]
        login.password = credentials[:password]
      end.submit

      $logger.info "(2/6) selecting daily reservation"
      page = page.link_with(:href => "/bart/reservations/facilities/?type=daily").click

      $logger.info "(3/6) selecting lafayette station"
      page = page.form_with(:action => "/bart/reservations/date/") do |form|
        form.radiobutton_with(:id => "type_id_40").check
      end.submit

      $logger.info "(4/6) attempting to reserve #{target}"
      # http://mechanize.rubyforge.org/Mechanize/Page.html
      page = page.form_with(:action => "/bart/reservations/date/") do |form|
        form.start_date =
          form.end_date = target.to_s
      end.submit

      if (page.body =~ /Reservations cannot be made more than two months in advance/)
        $logger.warn "too far in advance"
        return
      else
        date[:current] = target.succ
        File.open('date.yml', 'w') {|f| f.write date.to_yaml } #Store

        if (page.body =~ /This facility has no availability for the date range you selected. Please choose from one of the following facilities which do have availability,/)
          $logger.info "lafayette full, selecting orinda station"
          page = page.form_with(:action => "/bart/reservations/date/") do |form|
            button = form.radiobutton_with(:id => "type_id_37")
            if button.nil?
              $logger.warn "orinda is also full"
              return
            else
              button.check
            end
          end.submit
        end

        $logger.info "(5/6) reserving"
        page = page.form_with(:action => "/bart/reservations/reserve/").submit

        $logger.info "(6/6) agreeing to terms and conditions"
        page = page.link_with(:href => /confirm/).click
        page = page.form_with(:id => "complete_form") do |form|
          form.checkbox_with(:name => "conditions").check
        end.submit

        $logger.info "getting permit"
        reservation = get_reservation @agent, target
        download_permit @agent, reservation['Permit #:']
      end
    rescue Exception => e
      $logger.error e.message
      $logger.error e.backtrace.inspect
    end
  end

end

Permitter.start
