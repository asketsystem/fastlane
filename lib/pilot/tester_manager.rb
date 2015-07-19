require "fastlane_core"

module Pilot
  class TesterManager < Manager
    def add_tester(options)
      self.run(options)

      begin
        tester = Spaceship::Tunes::Tester::Internal.find(config[:email])
        tester ||= Spaceship::Tunes::Tester::External.find(config[:email])

        if tester
          Helper.log.info "Existing tester #{tester.email}".green
        else
          tester = Spaceship::Tunes::Tester::External.create!(email: config[:email],
                                                              first_name: config[:first_name],
                                                              last_name: config[:last_name],
                                                              group: config[:group_name])
          Helper.log.info "Successfully invited tester: #{tester.email}".green
        end
        
        app_filter = (config[:apple_id] || config[:app_identifier])
        if app_filter
          begin
            tester.add_to_app!(app_filter)
            Helper.log.info "Successfully added tester to app #{app_filter}".green
          rescue => ex
            Helper.log.error "Could not add #{tester.email} to app: #{ex}".red
            raise ex
          end
        end
      rescue => ex
        Helper.log.error "Could not create tester #{config[:email]}".red
        raise ex
      end
    end

    def find_tester(options)
      self.run(options)

      tester = Spaceship::Tunes::Tester::Internal.find(config[:email])
      tester ||= Spaceship::Tunes::Tester::External.find(config[:email])

      raise "Tester #{config[:email]} not found".red unless tester
      
      describe_tester(tester)
      return tester
    end

    def remove_tester(options)
      self.run(options)
      
      tester = Spaceship::Tunes::Tester::External.find(config[:email])
      tester ||= Spaceship::Tunes::Tester::Internal.find(config[:email])

      if tester
        tester.delete!
        Helper.log.info "Successully removed tester #{tester.email}".green
      else
        Helper.log.error "Tester not found: #{config[:email]}".red
      end
    end

    private
      # Print out all the details of a specific tester
      def describe_tester(tester)
        return unless tester
        require 'terminal-table'

        rows = []

        rows << ["First name", tester.first_name]
        rows << ["Last name", tester.last_name]
        rows << ["Email", tester.email]

        groups = tester.raw_data.get("groups")

        if groups && groups.length > 0
          group_names = groups.map { |group| group["name"]["value"] }
          rows << ["Groups", group_names.join(', ')]
        end

        latestInstalledDate = tester.raw_data.get("latestInstalledDate")
        if latestInstalledDate
          latest_installed_version = tester.raw_data.get("latestInstalledVersion")
          latest_installed_short_version = tester.raw_data.get("latestInstalledShortVersion")
          pretty_date = Time.at((latestInstalledDate / 1000)).strftime("%m/%d/%y %H:%M")

          rows << ["Latest Version", "#{latest_installed_version} (#{latest_installed_short_version})"]
          rows << ["Latest Install Date", pretty_date]
        end

        if tester.devices.length == 0
          rows << ["Devices", "No devices"]
        else
          rows << ["#{tester.devices.count} Devices", ""]
          tester.devices.each do |device|
            current = "\u2022 #{device['model']}, iOS #{device['osVersion']}"

            if rows.last[1].length == 0
              rows.last[1] = current
            else
              rows << ["", current]
            end
          end
        end

        table = Terminal::Table.new(
          title: tester.email.green,
          # headings: ['Action', 'Description', 'Author'],
          rows: rows
        )
        puts table
      end
  end
end
