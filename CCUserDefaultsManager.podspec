Pod::Spec.new do |s|
  s.name         = "CCUserDefaultsManager"
  s.version      = "1.1"
  s.summary      = "使对NSUserDefaults的存取操作具有更高的内聚性.Make access to the NSUserDefaults operation has a higher cohesiveness."
  s.homepage     = "https://github.com/zhahao/CCUserDefaultsManager"
  s.license      = "MIT"
  s.author       = { "zhahao" => "506902638@qq.com" }
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/zhahao/CCUserDefaultsManager.git", :tag => s.version }
  s.source_files  = "CCUserDefaultsManager", "CCUserDefaultsManager/CCUserDefaultsManager/CCUserDefaultsManager/*.{h,m}"
  s.framework  = "UIKit"
end
