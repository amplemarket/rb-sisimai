require 'spec_helper'
require './spec/sisimai/lhost/code'
enginename = 'MessagingServer'
isexpected = [
  { 'n' => '01001', 'r' => /hostunknown/ },
  { 'n' => '01002', 'r' => /mailboxfull/ },
  { 'n' => '01003', 'r' => /filtered/ },
  { 'n' => '01004', 'r' => /mailboxfull/ },
  { 'n' => '01005', 'r' => /hostunknown/ },
  { 'n' => '01006', 'r' => /filtered/ },
  { 'n' => '01007', 'r' => /mailboxfull/ },
  { 'n' => '01008', 'r' => /filtered/ },
  { 'n' => '01009', 'r' => /mailboxfull/ },
  { 'n' => '01010', 'r' => /mailboxfull/ },
  { 'n' => '01011', 'r' => /expired/ },
  { 'n' => '01012', 'r' => /filtered/ },
  { 'n' => '01013', 'r' => /mailboxfull/ },
  { 'n' => '01014', 'r' => /mailboxfull/ },
  { 'n' => '01015', 'r' => /filtered/ },
  { 'n' => '01016', 'r' => /userunknown/ },
  { 'n' => '01017', 'r' => /notaccept/ },
  { 'n' => '01018', 'r' => /rejected/ },
  { 'n' => '01019', 'r' => /mailboxfull/ },
]
Sisimai::Lhost::Code.maketest(enginename, isexpected, true)

