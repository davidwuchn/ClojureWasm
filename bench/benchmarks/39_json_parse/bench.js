const doc = JSON.stringify({users: Array.from({length: 200}, (_, i) => ({
  id: i, name: `user${i}`, tags: ["alpha", "beta", "gamma"],
  scores: [1.5, 2.5, 3.5, 4.5], active: i % 2 === 0}))});
let acc = 0;
for (let i = 0; i < 100; i++) acc += JSON.parse(doc).users.length;
console.log(acc);
