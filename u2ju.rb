#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Author: TAC (tac@tac42.net)
# Converte Unity test result to JUnit xml format.

#################
# Test Results. #
#################
class TestResultPass
  def render(builder)
  end
end
class TestResultFailure
  attr_reader :type, :message, :detail

  def initialize(type, message="", detail="")
    @type, @message, @detail = type, message, detail
  end

  def render(builder)
    builder.failure({:type => @type, :message => @message}, @detail)
  end
end
class TestResultError
  attr_reader :type, :message, :detail

  def initialize(type, message="", detail="")
    @type, @message, @detail = type, message, detail
  end
end
class TestResultSkipped
  def render(builder)
    builder.skipped
  end
end

#############
# Test Case #
#############
class TestCase
  attr_reader :classname, :name, :time, :result

  def initialize(classname, name, time, result)
    @classname, @name, @time, @result = classname, name, time, result
  end

  def render(builder)
    builder.testcase({:classname => @classname, :name => @name, :time =>@time}){
      @result.render(builder)
    }
  end
end

##############
# Test Suite #
##############
class TestSuite
  attr_reader :tests, :errors, :failures, :time, :cases

  def initialize(tests, errors, failures, time)
    @tests, @errors, @failures, @time = tests, errors, failures, time
    @cases = []
  end

  def add_case(test_case)
    @cases << test_case
  end

  def add_cases(test_cases)
    @cases += test_cases
  end

  def render(builder)
    builder.testsuite({:tests => @tests, :errors => @errors, :failures => @failures, :time => @time}){
      @cases.each{ |c|
        c.render(builder)
      }
    }
  end
end


def gen_suite(cases)
  return nil if cases.empty?

  e = cases.count{|c| c.result.class == TestResultError}
  f = cases.count{|c| c.result.class == TestResultFailure}

  suite = TestSuite.new(cases.size, e, f, "0")
  suite.add_cases(cases)

  return suite
end


# parsing.
lines = STDIN.read.split("\n").map(&:strip)

i = 0
suites = []
cases = []
while i < lines.size

  case lines[i]
  when /^Unity test run (\d) of (\d)$/
    if !cases.empty?
      suites << gen_suite(cases)
      cases.clear
    end

  when /^TEST\((.+), (.+)\)(.*)/
    group, name, isPass = [$1, $2, $3].map(&:strip)

    res = case  isPass
          when "PASS"
            TestResultPass.new
          else

            fxn_file, line, c_name, result, message = lines[i,2].join.split(":").map(&:strip)

            fxn_file =~ /(.+?\))(.+)/
            fxn, file = $1, $2

            message ||= ""
            full_message = ["#{file} L#{line}", fxn, message].join(", ")

            c_name =~ /^TEST\((.+), (.+)\)/
            group, name, isPass = [$1, $2].map(&:strip)

            case result
            when "FAIL"
              TestResultFailure.new("TestFailed", message, full_message)
            when "IGNORE"
              TestResultSkipped.new
            end
          end

    cases << TestCase.new(group, name, "0.0", res)
  end

  i += 1
end

suites << gen_suite(cases)

# building.
require 'builder'

builder = Builder::XmlMarkup.new :indent => 2
builder.instruct! :xml, :version => "1.0", :encoding => "UTF-8"

suites.each do |s|
  puts s.render(builder)
end
