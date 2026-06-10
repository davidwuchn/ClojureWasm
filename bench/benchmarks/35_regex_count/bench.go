package main

import (
	"fmt"
	"regexp"
)

func main() {
	re := regexp.MustCompile(`\d+`)
	s := "a12b345c6789d0e"
	c := 0
	for i := 0; i < 10000; i++ {
		c = len(re.FindAllString(s, -1))
	}
	fmt.Println(c)
}
