resource "aws_vpc_endpoint" "s3_ep" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  
  route_table_ids = var.private_routes_ids
  #manually added the main current rt
  #need to add data too
}

