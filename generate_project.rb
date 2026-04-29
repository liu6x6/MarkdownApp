require 'xcodeproj'

project_path = './MarkdownApp.xcodeproj'
project = Xcodeproj::Project.new(project_path)

# Add targets
app_target = project.new_target(:application, 'MarkdownApp', :osx, '14.0')
ios_target = project.new_target(:application, 'MarkdownApp_iOS', :ios, '16.0')

# Configure macOS target
app_target.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.example.MarkdownApp"
  config.build_settings['INFOPLIST_KEY_LSApplicationCategoryType'] = 'public.app-category.utilities'
  config.build_settings['INFOPLIST_KEY_CFBundleDocumentTypes'] = [
    {
      'CFBundleTypeName' => 'Markdown Document',
      'CFBundleTypeRole' => 'Editor',
      'LSHandlerRank' => 'Default',
      'LSItemContentTypes' => ['net.daringfireball.markdown', 'public.plain-text']
    }
  ]
end

# Configure iOS target
ios_target.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.example.MarkdownApp.ios"
  config.build_settings['TARGETED_DEVICE_FAMILY'] = "1,2" # iPhone & iPad
  config.build_settings['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UIFileSharingEnabled'] = 'YES'
  config.build_settings['INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace'] = 'YES'
end

# Add files to targets
app_group = project.main_group.find_subpath('MarkdownApp', true)
tests_group = project.main_group.find_subpath('MarkdownAppTests', true)
uitests_group = project.main_group.find_subpath('MarkdownAppUITests', true)

# Helper to recursively add files
def add_files(dir, group, mac_target, ios_target, project)
  Dir.glob("#{dir}/*").each do |file|
    if File.directory?(file)
      subgroup = group.new_group(File.basename(file))
      add_files(file, subgroup, mac_target, ios_target, project)
    else
      file_ref = group.new_file(file)
      if file.end_with?('.swift')
        mac_target.source_build_phase.add_file_reference(file_ref)
        ios_target.source_build_phase.add_file_reference(file_ref)
      elsif file.end_with?('.css') || file.end_with?('.js') || file.end_with?('.md')
        mac_target.resources_build_phase.add_file_reference(file_ref)
        ios_target.resources_build_phase.add_file_reference(file_ref)
      end
    end
  end
end

add_files('MarkdownApp', app_group, app_target, ios_target, project)

project.save
puts "Project generated successfully."
