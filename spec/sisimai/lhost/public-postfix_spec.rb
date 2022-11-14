require 'spec_helper'
require './spec/sisimai/lhost/code'
enginename = 'Postfix'
isexpected = [
  { 'n' => '01', 's' => /\A5[.]1[.]1\z/,   'r' => /mailererror/,   'b' => /\A1\z/ },
  { 'n' => '02', 's' => /\A5[.][12][.]1\z/,'r' => /(?:filtered|userunknown)/, 'b' => /\d\z/ },
  { 'n' => '03', 's' => /\A5[.]0[.]0\z/,   'r' => /filtered/,      'b' => /\A1\z/ },
  { 'n' => '04', 's' => /\A5[.]1[.]1\z/,   'r' => /userunknown/,   'b' => /\A0\z/ },
  { 'n' => '05', 's' => /\A4[.]1[.]1\z/,   'r' => /userunknown/,   'b' => /\A0\z/ },
  { 'n' => '06', 's' => /\A5[.]4[.]4\z/,   'r' => /hostunknown/,   'b' => /\A0\z/ },
  { 'n' => '07', 's' => /\A5[.]0[.]\d+\z/, 'r' => /filtered/,      'b' => /\A1\z/ },
  { 'n' => '08', 's' => /\A4[.]4[.]1\z/,   'r' => /expired/,       'b' => /\A1\z/ },
  { 'n' => '09', 's' => /\A4[.]3[.]2\z/,   'r' => /toomanyconn/,   'b' => /\A1\z/ },
  { 'n' => '10', 's' => /\A5[.]1[.]8\z/,   'r' => /rejected/,      'b' => /\A1\z/ },
  { 'n' => '11', 's' => /\A5[.]1[.]8\z/,   'r' => /rejected/,      'b' => /\A1\z/ },
  { 'n' => '13', 's' => /\A5[.]2[.][12]\z/,'r' => /(?:userunknown|mailboxfull)/, 'b' => /\d\z/ },
  { 'n' => '14', 's' => /\A5[.]1[.]1\z/,   'r' => /userunknown/,   'b' => /\A0\z/ },
  { 'n' => '15', 's' => /\A4[.]4[.]1\z/,   'r' => /expired/,       'b' => /\A1\z/ },
  { 'n' => '16', 's' => /\A5[.]1[.]6\z/,   'r' => /hasmoved/,      'b' => /\A0\z/ },
  { 'n' => '17', 's' => /\A5[.]4[.]4\z/,   'r' => /networkerror/,  'b' => /\A1\z/ },
  { 'n' => '28', 's' => /\A5[.]7[.]1\z/,   'r' => /policyviolation/, 'b' => /\A1\z/ },
  { 'n' => '29', 's' => /\A5[.]7[.]1\z/,   'r' => /policyviolation/, 'b' => /\A1\z/ },
  { 'n' => '30', 's' => /\A5[.]4[.]1\z/,   'r' => /userunknown/,   'b' => /\A0\z/ },
  { 'n' => '31', 's' => /\A5[.]1[.]1\z/,   'r' => /userunknown/,   'b' => /\A0\z/ },
  { 'n' => '32', 's' => /\A5[.]1[.]1\z/,   'r' => /userunknown/,   'b' => /\A0\z/ },
  { 'n' => '33', 's' => /\A5[.]1[.]1\z/,   'r' => /userunknown/,   'b' => /\A0\z/ },
  { 'n' => '34', 's' => /\A5[.]0[.]\d+\z/, 'r' => /networkerror/,  'b' => /\A1\z/ },
  { 'n' => '35', 's' => /\A5[.]0[.]0\z/,   'r' => /filtered/,      'b' => /\A1\z/ },
  { 'n' => '36', 's' => /\A5[.]0[.]0\z/,   'r' => /userunknown/,   'b' => /\A0\z/ },
  { 'n' => '37', 's' => /\A4[.]4[.]1\z/,   'r' => /expired/,       'b' => /\A1\z/ },
  { 'n' => '38', 's' => /\A4[.]0[.]0\z/,   'r' => /blocked/,       'b' => /\A1\z/ },
  { 'n' => '39', 's' => /\A5[.]6[.]0\z/,   'r' => /spamdetected/,  'b' => /\A1\z/ },
  { 'n' => '40', 's' => /\A4[.]0[.]0\z/,   'r' => /systemerror/,   'b' => /\A1\z/ },
  { 'n' => '41', 's' => /\A5[.]0[.]0\z/,   'r' => /policyviolation/, 'b' => /\A1\z/ },
  { 'n' => '42', 's' => /\A5[.]0[.]0\z/,   'r' => /policyviolation/, 'b' => /\A1\z/ },
  { 'n' => '43', 's' => /\A4[.]3[.]0\z/,   'r' => /mailererror/,   'b' => /\A1\z/ },
  { 'n' => '44', 's' => /\A5[.]7[.]1\z/,   'r' => /norelaying/,    'b' => /\A1\z/ },
  { 'n' => '45', 's' => /\A4[.]3[.]0\z/,   'r' => /mailboxfull/,   'b' => /\A1\z/ },
  { 'n' => '46', 's' => /\A5[.]0[.]0\z/,   'r' => /userunknown/,   'b' => /\A0\z/ },
  { 'n' => '47', 's' => /\A5[.]0[.]0\z/,   'r' => /systemerror/,   'b' => /\A1\z/ },
  { 'n' => '48', 's' => /\A5[.]0[.]0\z/,   'r' => /toomanyconn/,   'b' => /\A1\z/ },
  { 'n' => '49', 's' => /\A4[.]0[.]0\z/,   'r' => /blocked/,       'b' => /\A1\z/ },
  { 'n' => '50', 's' => /\A4[.]0[.]0\z/,   'r' => /blocked/,       'b' => /\A1\z/ },
  { 'n' => '51', 's' => /\A5[.]7[.]0\z/,   'r' => /policyviolation/, 'b' => /\A1\z/ },
  { 'n' => '52', 's' => /\A5[.]0[.]0\z/,   'r' => /suspend/,       'b' => /\A1\z/ },
  { 'n' => '53', 's' => /\A5[.]0[.]0\z/,   'r' => /syntaxerror/,   'b' => /\A1\z/ },
  { 'n' => '54', 's' => /\A5[.]7[.]1\z/,   'r' => /rejected/,      'b' => /\A1\z/ },
  { 'n' => '55', 's' => /\A5[.]0[.]0\z/,   'r' => /toomanyconn/,   'b' => /\A1\z/ },
  { 'n' => '56', 's' => /\A4[.]4[.]2\z/,   'r' => /networkerror/,  'b' => /\A1\z/ },
  { 'n' => '57', 's' => /\A5[.]2[.]1\z/,   'r' => /userunknown/,   'b' => /\A0\z/ },
  { 'n' => '58', 's' => /\A5[.]7[.]1\z/,   'r' => /blocked/,       'b' => /\A1\z/ },
  { 'n' => '59', 's' => /\A5[.]2[.]1\z/,   'r' => /toomanyconn/,   'b' => /\A1\z/ },
  { 'n' => '60', 's' => /\A4[.]0[.]0\z/,   'r' => /blocked/,       'b' => /\A1\z/ },
  { 'n' => '61', 's' => /\A5[.]0[.]0\z/,   'r' => /suspend/,       'b' => /\A1\z/ },
  { 'n' => '62', 's' => /\A5[.]0[.]0\z/,   'r' => /virusdetected/, 'b' => /\A1\z/ },
  { 'n' => '63', 's' => /\A5[.]2[.]2\z/,   'r' => /mailboxfull/,   'b' => /\A1\z/ },
  { 'n' => '64', 's' => /\A5[.]0[.]\d+\z/, 'r' => /undefined/,     'b' => /\A1\z/ },
  { 'n' => '65', 's' => /\A5[.]0[.]0\z/,   'r' => /securityerror/, 'b' => /\A1\z/ },
  { 'n' => '66', 's' => /\A5[.]7[.]9\z/,   'r' => /policyviolation/, 'b' => /\A1\z/ },
  { 'n' => '67', 's' => /\A5[.]7[.]9\z/,   'r' => /policyviolation/, 'b' => /\A1\z/ },
  { 'n' => '68', 's' => /\A5[.]0[.]0\z/,   'r' => /policyviolation/, 'b' => /\A1\z/ },
  { 'n' => '69', 's' => /\A5[.]7[.]9\z/,   'r' => /policyviolation/, 'b' => /\A1\z/ },
  { 'n' => '70', 's' => /\A5[.]7[.]26\z/,  'r' => /policyviolation/, 'b' => /\A1\z/ },
  { 'n' => '71', 's' => /\A5[.]7[.]1\z/,   'r' => /policyviolation/, 'b' => /\A1\z/ },
  { 'n' => '72', 's' => /\A5[.]7[.]1\z/,   'r' => /policyviolation/, 'b' => /\A1\z/ },
  { 'n' => '73', 's' => /\A5[.]7[.]1\z/,   'r' => /policyviolation/, 'b' => /\A1\z/ },
  { 'n' => '74', 's' => /\A4[.]7[.]0\z/,   'r' => /blocked/,       'b' => /\A1\z/ },
]
Sisimai::Lhost::Code.maketest(enginename, isexpected)

