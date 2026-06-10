package main

import (
	"fmt"
	"math/big"
)

func main() {
	var f *big.Int
	for i := 0; i < 1000; i++ {
		f = big.NewInt(1)
		for k := int64(2); k <= 100; k++ {
			f.Mul(f, big.NewInt(k))
		}
	}
	fmt.Println(len(f.String()))
}
