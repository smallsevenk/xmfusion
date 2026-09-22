Pod::Spec.new do |s|
  s.name             = 'fusion'
  s.version          = '4.10.3'
  s.summary          = 'Generic single-engine, multi-container Flutter hybrid stack runtime.'
  s.description      = 'Reference runtime for embedding Flutter routes in Android and iOS containers.'
  s.homepage         = 'https://example.invalid/hybrid-stack-reference'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Reference Maintainers' => 'maintainers@example.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '9.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES'
  }
  s.swift_version = '5.0'
end
