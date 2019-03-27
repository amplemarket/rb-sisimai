require 'spec_helper'
require './spec/sisimai/bite/email/code'
enginename = 'EZweb'
isexpected = [
  { 'n' => '01', 's' => /\A5[.]0[.]\d+\z/, 'r' => /filtered/,    'b' => /\A1\z/ },
  { 'n' => '02', 's' => /\A5[.]0[.]\d+\z/, 'r' => /suspend/,     'b' => /\A1\z/ },
  { 'n' => '03', 's' => /\A5[.]0[.]\d+\z/, 'r' => /suspend/,     'b' => /\A1\z/ },
  { 'n' => '04', 's' => /\A5[.]0[.]\d+\z/, 'r' => /userunknown/, 'b' => /\A0\z/ },
  { 'n' => '05', 's' => /\A5[.]0[.]\d+\z/, 'r' => /expired/,     'b' => /\A1\z/ },
  { 'n' => '07', 's' => /\A5[.]0[.]\d+\z/, 'r' => /userunknown/, 'b' => /\A0\z/ },
  { 'n' => '08', 's' => /\A5[.]0[.]\d+\z/, 'r' => /blocked/,     'b' => /\A1\z/ },
]
Sisimai::Bite::Email::Code.maketest(enginename, isexpected)

