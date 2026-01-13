package main

import (
	"os"

	gql "github.com/mununki/gqlmerge/lib"
)

func main() {
	typeDefsDir := "graphql-definitions"
	files, err := os.ReadDir(typeDefsDir)
	if err != nil {
		panic(err)
	}
	var typeDefPaths []string
	for _, file := range files {
		if !file.IsDir() {
			typeDefPaths = append(typeDefPaths, typeDefsDir+"/"+file.Name())
		}
	}
	schema := gql.Merge(" ", typeDefPaths...)
	outputFile, err := os.Create("go.generated.graphql")
	if err != nil {
		panic(err)
	}
	defer outputFile.Close()
	_, err = outputFile.WriteString(*schema)
	if err != nil {
		panic(err)
	}
}
