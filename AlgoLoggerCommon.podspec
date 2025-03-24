#
# Be sure to run `pod lib lint AlgoLoggerCommon.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AlgoLoggerCommon'
  s.version          = '2.1.0'
  s.summary          = 'Logger Common Library of Algorigo'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
    AlgoLogger is a logger library of Algorigo. It is a simple and easy-to-use logger library that can be used in iOS projects.
                       DESC

  s.homepage         = 'https://github.com/Algorigo/AlgoLogger_iOS'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'rouddy' => 'rouddy@naver.com' }
  s.source           = { :git => 'https://github.com/Algorigo/AlgoLogger_iOS.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '13.0'

  s.source_files = 'AlgoLoggerCommon/**/*'

  # s.resource_bundles = {
  #   'AlgoLoggerCommon' => ['AlgoLoggerCommon/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'

end