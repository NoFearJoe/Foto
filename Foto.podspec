Pod::Spec.new do |s|

  s.name = 'Foto'
  s.summary = 'Easy to use gallery content provider written in Swift'
  s.authors = 'nofearjoe'
  s.homepage = 'https://github.com/NoFearJoe'
  s.license = { :type => 'MIT' }

  s.version = '0.2'
  s.source = { :git => 'https://github.com/NoFearJoe/Foto.git', :tag => s.version.to_s }

  s.platform = :ios
  s.ios.deployment_target = '9.0'
  s.requires_arc = true

  s.source_files = 'Foto/Foto/Sources/**/*.{swift}'

end
