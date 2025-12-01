# Seed canonical topics and tags for composer filters.
puts 'Seeding database...'

TaxonomySeeder.seed!

puts "Seeding completed!"
puts "  Topics: #{Topic.count}"
puts "  Tags: #{Tag.count}"

# Verify minimum requirements
if Topic.count.zero? || Tag.count.zero?
  puts "WARNING: Seeding may have failed. Topics or tags are missing."
else
  puts "Database is ready for use."
end
