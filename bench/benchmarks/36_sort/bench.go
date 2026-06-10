package main

import (
	"fmt"
	"sort"
)

func main() {
	var total int
	for it := 0; it < 5; it++ {
		v := make([]int, 5000)
		for i := 0; i < 5000; i++ {
			v[i] = 5000 - i
		}
		sort.Ints(v)
		total = 0
		for i := 0; i < 100; i++ {
			total += v[i]
		}
	}
	fmt.Println(total)
}
