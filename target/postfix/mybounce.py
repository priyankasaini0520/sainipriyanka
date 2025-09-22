#!/usr/bin/python3

import sys
import smtplib
import email
from email import encoders
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

def main(argv):
  msg_lines = sys.stdin.readlines()
  raw_message = ''.join(msg_lines)
  vmsg = email.message_from_string(raw_message)
  subject = vmsg.get('Subject', '(no subject)')

  mailfrom = vmsg.get('From', 'testqa@fss.qa.campaign.adobe.com')
  mailto = msg_lines[0].split(' ')[1]

  with open("/var/tmp/mybounce.log", "a") as file:
    file.write("-----------\n")
    file.write(vmsg.as_string())
    file.write(''.join(msg_lines))
    file.write(mailto)
    file.write("\n")

  #create email
  mail = MIMEMultipart()
  mail['Subject'] = subject
  mail['To'] = mailto
  mail['From'] = mailfrom
  mail.attach(MIMEText('user unknown', 'plain'))

  #attach original mail
  amsg = MIMEBase('message', 'rfc822')
  amsg.set_payload(raw_message)
  amsg.add_header('Content-Disposition', 'attachment', filename='mail.eml')
  mail.attach(amsg)
  
  #send
  s = smtplib.SMTP('localhost')
  s.sendmail(mailfrom, mailto, mail.as_string())
  s.quit()

if __name__ == "__main__":
  main(sys.argv)
