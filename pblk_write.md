# pblk写流程
## 写流程

1. pblk-cache.c

        int pblk_write_to_cache(...)
        {
            sector_t lba = pblk_get_lba(bio); //从bio结构体获取逻辑地址
            pblk_ppa_set_empty(&w_ctx.ppa);  //置ppa为空，也就是还没有分配物理地址
            pblk_rb_write_entry_user(..)   //pblk-rb.c 写入到ring buffer
            pblk_write_should_kick(pblk);  //唤醒pblk写线程（读cache，写入设备）
        }

2. pblk-rb.c:304

        void pblk_rb_write_entry_user(...)
        {
            __pblk_rb_write_entry(rb, data, w_ctx, entry);  //memcpy 写入到ring buffer缓存
            pblk_update_map_cache(pblk, w_ctx.lba, entry->cacheline);  //更新l2p表
            //此时当前逻辑地址对应的物理地址是一个指向cache的标记,即entry->cacheline
            //对当前逻辑地址的读操作会直接从cache中进行
        }
                
        2.1
            pblk_update_map_cache(struct pblk *pblk, sector_t lba, struct ppa_addr ppa){
            pblk_update_map(struct pblk *pblk, sector_t lba, struct ppa_addr ppa);   //更新map
            }
        2.2
            pblk_update_map(){
                l2p_ppa = pblk_trans_map_get(pblk, lba);   //得到逻辑地址对应的物理地址
                /*如果失效的话，地址置为无效*/
                pblk_trans_map_set(pblk, lba, ppa);
            }
3. pblk-write.c

        static int pblk_submit_write(struct pblk *pblk)
        {
            pblk_rb_read_to_bio(...)  //从ring buffer缓存中读取到bio

            pblk_submit_io_set(...)   //提交bio
        }
        static int pblk_submit_io_set(struct pblk *pblk, struct nvm_rq *rqd)
        {
            pblk_setup_w_rq(pblk, rqd, c_ctx, &erase_ppa);  //创建request
                3.1 pblk_setup_w_rq(){
                        struct pblk_line *e_line = pblk_line_get_erase(pblk); //
                        pblk_map_rq(pblk, rqd, c_ctx->sentry, lun_bitmap, valid, 0);//调用pblk_map_rq()来管理l2p表
                 }
                3.2 pblk_map_rq(){
                        pblk_map_page_data();    //pblk_map_rq()调用了pblk_map_page_data()
                }
            //分配物理地址ppa并对其加锁(信号量)
            
            
            pblk_submit_io(pblk, rqd);  //返回nvm_submit_io(dev, rqd)，提交request到nvm层  in pblk-core.c
        }
  

4. pblk-map.c

        pblk_map_page_data(...)
        {
            struct pblk_line *line = pblk_line_get_data(pblk);  //获取pblk的data line（当前用来写入数据的line）

            paddr = pblk_alloc_page(pblk, line, nr_secs);  //从当前line中分配一个页

            ppa_list[i] = addr_to_gen_ppa(pblk, paddr, line->id);  //循环获取ppa地址
            w_ctx->ppa = ppa_list[i];   //将ppa赋值给w_ctx（每个w_ctx是一个bio的写请求的上下文）
             //这一步才真正的给逻辑地址分配了物理地址
             //但是还找不到具体如何update了l2p表。。。

            pblk_down_rq(pblk, ppa_list, nr_secs, lun_bitmap);  加锁  pblk-core.c
        }

## GC写流程

1.      pblk_write_gc_to_cache（...）{
                 pblk_ppa_set_empty(&w_ctx.ppa);  //置ppa为空，也就是还没有分配物理地址
                 pblk_rb_write_entry_gc(&pblk->rwb, data, w_ctx, gc_line, pos);    //pblk-rb.c GC 写入到ring buffer
                 pblk_write_should_kick(pblk);  //唤醒pblk写线程（读cache，写入设备）
        }
2.       pblk_rb_write_entry_gc(&pblk->rwb, data, w_ctx, gc_line, pos){
        _pblk_rb_write_entry(rb, data, w_ctx, entry);       //memcpy 写入到ring buffer缓存
        pblk_update_map_gc(pblk, w_ctx.lba, entry->cacheline, gc_line); //更新GC map
      }
     2.1         pblk_update_map_gc(struct pblk *pblk, sector_t lba, struct ppa_addr ppa,struct pblk_line *gc_line){
                        l2p_ppa = pblk_trans_map_get(pblk, lba);   //得到逻辑地址对应的物理地址
                        /*如果失效，重置新的*/
                        pblk_trans_map_set(pblk, lba, ppa);
               }
      
            
                
