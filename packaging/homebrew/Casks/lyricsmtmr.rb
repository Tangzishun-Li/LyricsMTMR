# 计划板第 20 条：Homebrew Cask 配方（待开发者账号就绪后提交 homebrew-cask）。
#
# 用法（本地试用）：
#   brew install --cask ./packaging/homebrew/Casks/lyricsmtmr.rb
#
# 发版时由 packaging/update-cask.sh 把 version / sha256 写进来（见 docs/公证与Cask.md）。
cask "lyricsmtmr" do
  version "0.3.6"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/Tangzishun-Li/LyricsMTMR/releases/download/v#{version}/LyricsMTMR-v#{version}.dmg",
      verified: "github.com/Tangzishun-Li/LyricsMTMR/"
  name "LyricsMTMR"
  desc "Touch Bar Now Playing workstation with karaoke lyrics"
  homepage "https://github.com/Tangzishun-Li/LyricsMTMR"

  depends_on macos: ">= :sequoia"

  app "LyricsMTMR.app"

  zap trash: [
    "~/Library/Application Support/LyricsMTMR",
    "~/Library/Preferences/com.toxblh.mtmr.plist",
  ]
end
