require 'safe_yaml'
require 'uri'

def strip_or_self!(str)
  str.strip! || str if str
end

def sanitize_yaml_string!(str, name)
  sanatized = strip_or_self!(str)
  sanatized = sanatized.sub(name + ": ", "")
                       .sub(name + " : ", "")

  if (sanatized.start_with?("\"") && sanatized.end_with?("\"")) ||
    (sanatized.start_with?("'") && sanatized.end_with?("'")) then
    sanatized = sanatized.sub(/^\"/, "")
             .sub(/\"$/, "")
             .sub(/^'/, "")
             .sub(/\'$/, "")
  end

  strip_or_self!(sanatized)
end

def check_folder
  # i'm lazy
  root = File.expand_path("..", __dir__)

  all_files =  Dir[root + "/_data/projects/*"]
  yaml_files =  Dir[root + "/_data/projects/*.yml"]

  # i'm lazy, there's gotta be an easier way to do this!
  yaml_files.each { |f| all_files.delete f }
  other_files = all_files.count

  if (other_files > 0) then
    puts "#{other_files} files in directory which are not YAML files:"
    all_files.each { |f| puts " - " + f }
    exit -1
  end
end

def valid_url? (url)
   begin
    uri = URI.parse(url)
    uri.kind_of?(URI::HTTP) || uri.kind_of?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end
end

def verify_preferred_tag (tag)
  # preference is a map of [bad tag]: [preferred tag]
  preference = {
    "algorithms" => "algorithm",
    "appletv" => "apple-tv",
    "asp-net" => "asp.net",
    "aspnet" => "asp.net",
    "aspnetmvc" => "aspnet-mvc",
    "aspnetcore" => "aspnet-core",
    "asp-net-core" => "aspnet-core",
    "assembler" => "assembly",
    "builds" => "build",
    "collaborate" => "collaboration",
    "coding" =>"code",
    "colour" => "color",
    "commandline" => "command-line",
    "csharp" => "c#",
    "docs" => "documentation",
    "dotnet-core" => ".net core",
    "encrypt" => "encryption",
    "fsharp" => "f#",
    "games" => "game",
    "gatsby" => "gatsbyjs",
    "golang" => "go",
    "js" => "javascript",
    "library" => "libraries",
    "linters" => "linter",
    "node" => "node.js",
    "nodejs" => "node.js",
    "nuget.exe" => "nuget",
    "parser" => "parsing",
    "react" => "reactjs",
  }
  if (preference[tag] != nil) then
    return "Use '#{preference[tag]}' instead of #{tag}\n"
  end
  return ""
end

def verify_tags(taglist)
  result = ""
  taglist.each do |tag|
    if(tag =~ /[A-Z]/) then
      result += "Tag '#{tag}' contains uppercase characters\n"
    end
    if(tag =~ /[\s_]/) then
      result += "Tag '#{tag}' contains spaces or '_' (should use '-' instead)\n"
    end
    result += verify_preferred_tag(tag)
  end
  if result != "" then
    return "\nTag verification failed!\n" + result
  end
  return result
end

def verify_file (f)
  begin
    contents = File.read(f)

    dotNetInQuote = contents.index("- .NET")

    if dotNetInQuote then
      error = "Please specify the .NET label in quotes"
      return [f, error]
    end

    yaml = YAML.load(contents, :safe => true)

    if yaml["name"].nil? then
      error = "Required 'name' attribute is not defined"
      return [f, error]
    end

    if yaml["site"].nil? then
      error = "Required 'site' attribute is not defined"
      return [f, error]
    end

    if !valid_url?(yaml["site"]) then
      error = "Required 'site' attribute to be a valid url"
      return [f, error]
    end

    if yaml["desc"].nil? then
      error = "Required 'desc' attribute is not defined"
      return [f, error]
    end

    tags = yaml["tags"]
    if tags.nil? || tags.empty? then
      error = "No tags defined for file"
      return [f, error]
    end

    tags_verification = verify_tags(tags)
    if !tags_verification.empty? then
      return [f, tags_verification]
    end

    dups = tags.group_by{ |e| e }.keep_if{|_, e| e.length > 1 }

    if dups.any? then
      tags = dups.keys.join ", "
      error = "Duplicate tags found: " + tags
      return [f, error]
    end

    if yaml["upforgrabs"].nil? then
      error = "Required 'upforgrabs' attribute is not defined"
      return [f, error]
    end

    if yaml["upforgrabs"]["name"].nil? then
      error = "Required 'upforgrabs.name' attribute is not defined"
      return [f, error]
    end

    if yaml["upforgrabs"]["link"].nil? then
      error = "Required 'upforgrabs.link' attribute is not defined"
      return [f, error]
    end

    if !valid_url?(yaml["upforgrabs"]["link"]) then
      error = "Required 'upforgrabs.link' attribute to be a valid url"
      return [f, error]
    end

  rescue Psych::SyntaxError => e
    error = "Unable to parse the contents of file - Line: #{e.line}, Offset: #{e.offset}, Problem: #{e.problem}"
    return [f, error]
  rescue
    error = "Unknown exception for file: " + $!.to_s
    return [f, error]
  end

  return [f, nil]
end

root = File.expand_path("..", __dir__)

check_folder

results = Dir[root + "/_data/projects/*.yml"].map { |f| verify_file(f) }

files_with_errors = results.select { |file, error| error != nil }
error_count = files_with_errors.count

success = results.select { |file, error| error.nil? }.count

if (error_count > 0) then
  puts "#{success} files processed - #{error_count} errors found:"
  files_with_errors.each { |path, error| puts path + " - " + error }
  exit -1
else
  puts "#{success} files processed - no errors found!"
end
