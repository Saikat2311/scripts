aws ec2 describe-instances \
  --instance-id $(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
  --query "Reservations[*].Instances[*].Tags[?Key=='Name'].Value" \
  --region us-west-2 --output text