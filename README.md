# AWS ECS over Managed EC2 Instances with LocalStack Lab

## Goal

Experiment with AWS ECS over Managed EC2 Instances with LocalStack using Terraform

## Dependencies

1. Terraform: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
2. LocalStack: https://docs.localstack.cloud/aws/getting-started/installation/
    1. Docker: https://docs.docker.com/get-started/get-docker/
    2. Pro subscription
3. Add the LocalStack Auth Token to your environment
   variables: https://docs.localstack.cloud/aws/getting-started/auth-token/

## How to run

1. `localstack start`
2. `terraform init`
3. `terraform test`
    1. This command will hang your terminal and never completes.
    2. Observe following in the LocalStack Logs/LocalStack Docker Container:
```text
2025-11-23T10:48:32.579  INFO --- [et.reactor-4] localstack.request.aws     : AWS ec2.RevokeSecurityGroupEgress => 200
2025-11-23T10:48:32.583  INFO --- [et.reactor-7] localstack.request.aws     : AWS ec2.AuthorizeSecurityGroupEgress => 200
2025-11-23T10:48:32.586 ERROR --- [et.reactor-5] l.aws.handlers.logging     : exception during call chain: argument of type 'NoneType' is not iterable
2025-11-23T10:48:32.590  INFO --- [et.reactor-5] localstack.request.aws     : AWS ecs.CreateCapacityProvider => 500 (InternalError)
```
Also in the LocalStack console:
```text
exception while calling ecs.CreateCapacityProvider: argument of type 'NoneType' is not iterableTraceback (most recent call last): File "/opt/code/localstack/.venv/lib/python3.13/site-packages/rolo/gateway/chain.py", line 166, in handle handler(self, self.context, response) ~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ File "/opt/code/localstack/.venv/lib/python3.13/site-packages/localstack/aws/handlers/service.py", line 118, in __call__ handler(chain, context, response) ~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^ File "/opt/code/localstack/.venv/lib/python3.13/site-packages/localstack/aws/handlers/service.py", line 88, in __call__ skeleton_response = self.skeleton.invoke(context) File "/opt/code/localstack/.venv/lib/python3.13/site-packages/localstack/aws/skeleton.py", line 155, in invoke return self.dispatch_request(serializer, context, instance) ~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ File "/opt/code/localstack/.venv/lib/python3.13/site-packages/localstack/aws/skeleton.py", line 169, in dispatch_request result = handler(context, instance) or {} ~~~~~~~^^^^^^^^^^^^^^^^^^^ File "/opt/code/localstack/.venv/lib/python3.13/site-packages/localstack/aws/skeleton.py", line 117, in __call__ return self.fn(*args, **kwargs) ~~~~~~~^^^^^^^^^^^^^^^^^ File "/opt/code/localstack/.venv/lib/python3.13/site-packages/localstack/pro/core/services/ecs/provider.py.enc", line 196, in create_capacity_provider def create_capacity_provider(D,context:RequestContext,name:String,cluster:String|_A=_A,auto_scaling_group_provider:AutoScalingGroupProvider|_A=_A,managed_instances_provider:CreateManagedInstancesProviderConfiguration|_A=_A,tags:Tags|_A=_A,**E)->CreateCapacityProviderResponse:A=context;C=get_store(A);B=CapacityProvider(A.account_id,A.region,name,auto_scaling_group_provider,tags);C.capacity_providers[name]=B;return CreateCapacityProviderResponse(capacityProvider=B.response_object) ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ File "/opt/code/localstack/.venv/lib/python3.13/site-packages/localstack/pro/core/services/ecs/models.py.enc", line 94, in __init__ def __init__(A,account_id:str,region_name:str,name:str,asg_details:dict[str,Any],tags:list[dict[str,str]]|_A):B=region_name;A._id=str(mock_random.uuid4());A.capacity_provider_arn=f"arn:{get_partition(B)}:ecs:{B}:{account_id}:capacity-provider/{name}";A.name=name;A.status=_F;A.auto_scaling_group_provider=A._prepare_asg_provider(asg_details);A.tags=tags;(A.update_status):str|_A=_A ~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^ File "/opt/code/localstack/.venv/lib/python3.13/site-packages/localstack/pro/core/services/ecs/models.py.enc", line 97, in _prepare_asg_provider if _C not in A:A[_C]={} ^^^^^^^^^^^ localstack.aws.api.core.CommonServiceException: exception while calling ecs.CreateCapacityProvider: argument of type 'NoneType' is not iterable
```
4. NOTE: I haven't tested it (exact this config) against the real AWS infra, my goal was to reproduce the 500 error.
