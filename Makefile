# LyricsMTMR — convenience build targets
# 用法：make build / make test / make archive / make clean

.PHONY: build test archive clean

build:
	./LyricsMTMR/Scripts/build.sh

test:
	./LyricsMTMR/Scripts/test.sh

archive:
	./LyricsMTMR/Scripts/archive.sh

clean:
	cd LyricsMTMR && rm -rf .build Release
