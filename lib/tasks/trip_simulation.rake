# frozen_string_literal: true

namespace :trip do
  desc "Seed a 4-round golf trip dry run with demo scores and write tmp/trip_sim_manifest.md"
  task simulate: :environment do
    host = ENV.fetch("TRIP_SIM_HOST", "http://localhost:3000")
    simulation = TripSimulation.call(host: host)
    puts "Trip simulation complete."
    puts "Event: #{simulation.event.name} (#{simulation.event.token})"
    puts "Manifest: #{TripSimulation::MANIFEST_PATH}"
    puts
    puts "Next steps:"
    puts "  1. Start the server:  bin/rails server"
    puts "  2. Open URLs from the manifest (local links auto-sign-in as commissioner)"
    puts "     Manual login if needed: #{host}/login"
    puts "     Email: trip-commissioner@dryrun.test  Password: trip2026"
    puts
    puts File.read(TripSimulation::MANIFEST_PATH)
  end
end
