# frozen_string_literal: true

namespace :trip do
  desc "Seed a 4-round golf trip dry run with demo scores and write tmp/trip_sim_manifest.md"
  task simulate: :environment do
    simulation = TripSimulation.call
  puts "Trip simulation complete."
  puts "Event: #{simulation.event.name} (#{simulation.event.token})"
  puts "Manifest: #{TripSimulation::MANIFEST_PATH}"
  puts
  puts File.read(TripSimulation::MANIFEST_PATH)
  end
end
