module Runkeeper
  require 'nokogiri'
  require 'open-uri'

  BASE_URL = 'http://www.runkeeper.com'
  USER_PATH = '/user/'

  # Location to store cached HTML (no trailing slash)
  CACHE_PATH = 'tmp'

  # Get the total mileage for a single user
  #
  # @param [String] user_name Which user to total activities for
  # @param [Integer] year Year to pull activities for
  # @param [Integer] month Month to pull activities for
  def self.monthly_miles(user_name, year, month)
    doc = retrieve_and_parse_activities_page(user_name)

    runkeeper_user = User.new(doc)

    total_miles = 0
    runkeeper_user.activities.each do |activity|
      break if activity.started_at < Date.new(year, month, 1)

      total_miles += activity.miles if activity.started_at.year == year && activity.started_at.month == month
    end

    total_miles
  end

  private

    # Get a Nokogiri object with the XML containing
    # the activity ist for the given user
    #
    # @return [Nokogiri] parsed XML of the activity page
    def self.retrieve_and_parse_activities_page(user_name)
      xml = find_and_parse_cached_activities_page(user_name)
      xml ||= open_url_and_cache_activities_page(user_name)
    end

    # Get the cached copy of the user's activity page if
    # it exists, parsed into Nokogiri
    #
    # @return [Nokogiri] parsed XML of the user's activity page
    def self.find_and_parse_cached_activities_page(user_name)
      return if !FileTest.exists? cache_file_name(user_name)

      Nokogiri::XML(IO.read(cache_file_name(user_name)))
    end

    # Connect to the web site, scraping the HTML for the user's
    # activity list
    #
    # @return [Nokogiri] parsed XML of the activities page
    def self.open_url_and_cache_activities_page(user_name)
      puts "   Downloading the activities for #{user_name}"

      # Be a good Net citizen and wait 1 second so we don't pound
      # their web site repeatedly
      sleep 1

      raw_html = open(url_for_user(user_name)).read

      cache_file(cache_file_name(user_name), raw_html)

      Nokogiri::HTML(raw_html)
    end

    def self.cache_file(path, contents)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') do |file|
        file.write(contents)
      end
    end

    # Get the url for a single user's activities
    #
    # @param [String] user name
    # @return [String]
    def self.url_for_user(user_name)
      "#{BASE_URL}#{USER_PATH}#{user_name}/activitylist"
    end

    # Determine the cache filename for the given user. To accomplish
    # daily cache expiration, add today's date to the cache filename
    def self.cache_file_name(user_name)
      "#{CACHE_PATH}/runkeeper.#{user_name}.activities.#{date_as_file_name(Date.today)}.xml"
    end

    # Convert the given date into the filename format used by
    # our user activity cache
    def self.date_as_file_name(date)
      date.strftime('%Y%m%d') # yyyymmdd
    end

  class User
    attr_reader :activities,
                :name

    # Build up a user object from the Nokogiri document
    #
    # @param [Nokogiri::XML::Document] doc Parsed XML from the runkeeper site representing a single user's activity page
    def initialize(doc)
      @xml_doc = doc

      # Get the user's full name from the page
      @name = @xml_doc.css('.username .usernameLinkNoSpace').text

      # Loop through the activities on the page
      @activities = []
      # Get the activity URL from each activity on the page
      @xml_doc.css('#activityHistoryMenu .menuItem').collect { |l| l.attr('link') }.each do |activity_url|
        @activities << Activity.new(activity_url)
      end
    end
  end

  class Activity
    attr_reader :path

    # Build up an Activity object from the Nokogiri document
    #
    # @param [String] URL for the activity page
    def initialize(path)
      @path = path
    end

    # Get the number of miles for this activity
    #
    # @return [Float] number of miles
    def miles
      parsed_activity.css('#statsDistance .mainText').text.to_f
    end

    # Get the timestamp of when the activity started
    #
    # @return [DateTime]
    def started_at
      DateTime.parse parsed_activity.at_css('#activityDateText .secondary').text.split('-').first
    end

    # Get the activity number (from the path)
    def number
      path.match(/(\d+)/)[0]
    end

    private

      # Get a Nokogiri object with the XML containing
      # the current activity's page
      #
      # @return [Nokogiri] parsed XML of the activity page
      def parsed_activity
        @parsed_activity ||= find_and_parse_cached_activity_page
        @parsed_activity ||= open_url_and_cache_activity_page
      end

      # Get the cached copy of the activity's page if
      # it exists, parsed into Nokogiri
      #
      # @return [Nokogiri] parsed XML of the activity page
      def find_and_parse_cached_activity_page
        return if !FileTest.exists? cache_file_name

        Nokogiri::XML(IO.read(cache_file_name))
      end

      # Connect to the web site, pulling the HTML for the activity
      #
      # @return [Nokogiri] parsed XML of the activity page
      def open_url_and_cache_activity_page
        puts "   Downloading the activity on #{path}"

        # Be a good Net citizen and wait 1 second so we don't pound
        # their web site repeatedly
        sleep 1

        raw_html = open(url).read

        # Cache the raw HTML
        self.class.cache_file(cache_file_name, raw_html)

        Nokogiri::HTML(raw_html)
      end

      # Get the url for a single user's activities
      #
      # @param [String] user name
      # @return [String]
      def url
        "#{BASE_URL}#{path}"
      end

      # Determine the cache filename for the current activity
      def cache_file_name
        "#{CACHE_PATH}/runkeeper.activity.#{number}.xml"
      end

  end
end

