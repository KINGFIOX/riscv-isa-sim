require_privilege(PRV_M);
set_pc_and_serialize(p->get_state()->mepc->read());
p->put_csr(CSR_MSTATUS, 0x1800);
