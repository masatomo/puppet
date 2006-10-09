require 'puppet'

Puppet::Server::Report.newreport(:store, :useyaml => true) do
    Puppet.setdefaults(:reporting,
        :reportdir => {:default => "$vardir/reports",
                :mode => 0750,
                :owner => "$user",
                :group => "$group",
                :desc => "The directory in which to store reports received from the
            client.  Each client gets a separate subdirectory."}
    )

    Puppet.config.use(:reporting)

    desc "Store the yaml report on disk"

    def mkclientdir(client, dir)
        config = Puppet::Config.new
        config.setdefaults("reportclient-#{client}",
            "clientdir-#{client}" => { :default => dir,
                :mode => 0750,
                :owner => "$user",
                :group => "$group"
            }
        )

        config.use("reportclient-#{client}")
    end

    def process(yaml)
        # We don't want any tracking back in the fs.  Unlikely, but there
        # you go.
        client = self.host.gsub("..",".")

        dir = File.join(Puppet[:reportdir], client)

        unless FileTest.exists?(dir)
            mkclientdir(client, dir)
        end

        # Now store the report.
        now = Time.now.gmtime
        name = %w{year month day hour min}.collect do |method|
            # Make sure we're at least two digits everywhere
            "%02d" % now.send(method).to_s
        end.join("") + ".yaml"

        file = File.join(dir, name)

        begin
            File.open(file, "w", 0640) do |f|
                f.puts yaml
            end
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            Puppet.warning "Could not write report for %s at %s: %s" %
                [client, file, detail]
        end

        # Only testing cares about the return value
        return file
    end
end

# $Id$