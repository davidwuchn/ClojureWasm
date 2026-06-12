import json

doc = json.dumps({"users": [{"id": i,
                             "name": f"user{i}",
                             "tags": ["alpha", "beta", "gamma"],
                             "scores": [1.5, 2.5, 3.5, 4.5],
                             "active": i % 2 == 0}
                            for i in range(200)]})
acc = 0
for _ in range(100):
    acc += len(json.loads(doc)["users"])
print(acc)
