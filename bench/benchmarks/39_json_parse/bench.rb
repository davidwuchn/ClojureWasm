require 'json'
doc = JSON.generate({users: (0...200).map { |i| {id: i, name: "user#{i}",
  tags: %w[alpha beta gamma], scores: [1.5, 2.5, 3.5, 4.5], active: i.even?}}})
acc = 0
100.times { acc += JSON.parse(doc)["users"].length }
puts acc
