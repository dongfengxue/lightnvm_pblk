#pblk-gc.c 代码流程结构简析：
GC搬移时统计相应可用sec的计数，sec的ref越大说明
代码流程如下，从1依次往下调用

1.      pblk_gc_line（）函数调用line_ws = mempool_alloc(pblk->line_ws_pool, GFP_KERNEL);
        创建内存池，存放line_ws(work struct)
        调用INIT_WORK(&line_ws->ws, pblk_gc_line_prepare_ws);

2.      pblk_gc_line_prepare_ws（），/*gc准备工作，调用初始化gc_line_ws函数*/
              ret = pblk_line_read_emeta(pblk, line, emeta_buf);  /*读末尾的元数据，不可用报错*/
              lba_list = pblk_recov_get_lba_list(pblk, emeta_buf); 
        调用INIT_WORK(&line_rq_ws->ws, pblk_gc_line_ws);  /**/        

3.       pblk_gc_line_ws()   /*GC工作启动函数，调用pblk_gc_move_valid_secs*/
              pblk_gc_move_valid_secs()();      //移动有用的secs
              mempool_free();    /*内存池空间释放*/
              
4.       pblk_gc_move_valid_secs()            /*搬移有用的secs*/
         调用pblk_submit_read_gc（）          /* Read from GC victim block */
         pblk_gc_writer_kick(&pblk->gc);      /*唤醒GC写线程，wake_up_process(gc->gc_writer_ts);*/
         
##pblk_GC_write()
*暂时没找到哪里调用，不过这个函数很是很重要的，下面讲解一下流程
GC要write的内容放在list双向链表里，首先调用list_cut_position(&w_list, &gc->w_list, gc->w_list.prev);   //list划分
来得到要写的list，对于每一条要写的list，pblk_write_gc_to_cache(）都将这条GC写放到cache中，统一写下去
list_del(&gc_rq->list);//删除请求的list
kref_put(&gc_rq->line->ref, pblk_line_put); ///* Write buffer L2P references -- */
