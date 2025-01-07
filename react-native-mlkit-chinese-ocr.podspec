require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = package['name']
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = package['description']
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.author       = package["author"]

  s.platform      = :ios, "10.0"
  s.source        = { :git => "https://github.com/bashen1/react-native-mlkit-chinese-ocr.git", :tag => "master" }

  s.source_files = "ios/**/*.{h,m,mm}"

  s.dependency "React"
  s.dependency "GoogleMLKit/TextRecognition", "2.6.0"
end
