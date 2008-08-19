#
# This module compacts the local variable names
#
# Copyright (C) Nikolay V. Nemshilov aka St.
#
class NamesCompactor
  extend FrontCompiler::JSCompactor::Util
  
  class << self
    def compact(str)
      if pos = (str =~ function_start_re)
        start = str[0, pos]
        stack = str[pos, str.size]
        
        func = stack[function_start_re]
        func = func[0, func.size-1]
        stack = stack[func.size, stack.size]
        
        arguments = find_block(stack, "(")
        stack = stack[arguments.size, stack.size]
        
        body = find_block(stack, "{")
        stack = stack[body.size, stack.size]
        
        body = compact(body) # <- recoursive internal functions compacting
        
        start + func + compact_names(arguments, body) + compact(stack)
      else
        str
      end
    end
    
  protected
    def function_start_re
      @@function_start_re ||= /[\s\(:;=\{^$]+function[\w\d\s_]*\(/im
    end
    
    # compacts the localnames of the function
    def compact_names(arguments, body)
      names = guess_names_map(body,
                arguments.scan(/[\w\d_]+/im).concat(
                  find_body_varnames(body)
                ).uniq.select{ |name| name.size > 1 }.sort)
      
      names.each do |name, replacement|
        [arguments, body].each do |str|
          str.gsub!(/([^\w\d_\.])#{name}([^\w\d_])/) do |match|
            $1 + replacement + $2
          end
        end
      end
      
      arguments + body
    end
    
    # creates a map of varnames and their replacements replacements
    def guess_names_map(body, names)
      names_map = { }
      used_renames = []
      
      names.each do |name|
        ('a'..'z').to_a.concat(('A'...'Z').to_a).unshift(name[/[a-z]/] || 'a').each do |rename|
          if !used_renames.include?(rename) and !body.match(/[^\w\d_\.]#{rename}[^\w\d_]/)
            names_map[name] = rename
            used_renames << rename
            break
          end
        end
      end
      
      names_map
    end
    
    # extracts localy defined varnames of the given function body block
    def find_body_varnames(body)
      # getting the body body
      body = body.strip
      body = body[1, body.size-2]
      
      names = []
      
      # removing the internal functions
      while pos = (body =~ function_start_re)
        start = body[0, pos]
        stack = body[pos, body.size]
        
        func = body[function_start_re]
        
        # getting the local functionames
        func.scan(/function\s+(.+?)\(/im) do |match|
          names << $1.dup
        end
        
        func = func[0, func.size-1]
        stack = stack[func.size, stack.size]
        
        args = find_block(stack, "(")
        stack = stack[args.size, stack.size]
       
        body.gsub! func+args+find_block(stack, "{"), ''
      end
      
      # removing functions calls blocks
      while pos = (body =~ /\(/)
        block = find_block(body[pos, body.size], "(")
        if body[0, pos] =~ /(if|for|while)\s*\Z/im
          body.gsub! block, "[#{block[1, block.size-2]}]"
        else
          body.gsub! block, ''
        end
      end
      
      
      
      # getting the vars definitions
      body.scan(/[\s\(:;=\{\[^$]+var\s(.*?)(;|$)/im) do |match|
        names.concat($1.dup.split(",").collect{ |token|
          token.split("=").first.strip
        })
      end
      
      names
    end
  end
end
