# Paymaster

This contract sponsors your job's execution. Functions are explicitly stated instead of providing an open-ended exec endpoint in the interests of security. Should probably make it pausable in the near future (disinclined to do so at 5 AM). Made the modifier an explicit if-clause each time following N.V.'s example; he says avoidance of modifier declaration economises gas. 

Jobs are to be managed via this contract if you register them in this way; you can transfer the ownership to yourself via the appropriate function (don't forget to accept the job transfer and to replenish your own job owner credits beforehand).