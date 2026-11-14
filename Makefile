# LyricsMTMR — convenience build targets
# 用法：make build / make test / make archive / make install / make install-bump / make clean

.PHONY: build test archive install install-bump clean smoke verify-release rebuild-appcast

build:
	./LyricsMTMR/Scripts/build.sh

test:
	./LyricsMTMR/Scripts/test.sh

archive:
	./LyricsMTMR/Scripts/archive.sh

# 构建 Release 并装进 /Applications，让启动台打开的是最新版本。
install:
	./LyricsMTMR/Scripts/install.sh --refresh-dock

# 同上，但先把 build 号 +1，便于在「关于」/启动台里区分新旧构建。
install-bump:
	./LyricsMTMR/Scripts/install.sh --refresh-dock --bump

clean:
	cd LyricsMTMR && rm -rf .build Release

# 发布前打包冒烟：archive + zip + Info.plist + Sparkle 嵌入校验（CI 同款）
smoke:
	./LyricsMTMR/Scripts/package_smoke.sh

# 校验线上发布产物：feed/资产/sha256/enclosure（默认 latest，可 make verify-release TAG=v0.3.5-preview）
verify-release:
	python3 LyricsMTMR/Scripts/verify_release.py --tag $(or $(TAG),latest) --download

# 从真实 release 重写仓库根 appcast.xml（派生文件，不要手改）
rebuild-appcast:
	python3 LyricsMTMR/Scripts/rebuild_appcast.py --output appcast.xml
