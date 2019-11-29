require 'spec_helper'
require './spec/sisimai/lhost/code'
enginename = 'AmazonWorkMail'
isexpected = [
  { 'n' => '01001', 'r' => /userunknown/ },
  { 'n' => '01002', 'r' => /filtered/ },
  { 'n' => '01003', 'r' => /systemerror/ },
  { 'n' => '01004', 'r' => /mailboxfull/ },
  { 'n' => '01005', 'r' => /expired/ },
  { 'n' => '01006', 'r' => /mailboxfull/ },
]
Sisimai::Lhost::Code.maketest(enginename, isexpected, true)

