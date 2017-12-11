# pblk-gc.c 代码流程结构简析：

## pblk_gc_init 
1. gc->gc_ts = kthread_create(pblk_gc_ts, pblk, "pblk-gc-ts");   //创建内核gc线程
2. gc->gc_writer_ts = kthread_create(pblk_gc_writer_ts, pblk, "pblk-gc-writer-ts"); //创建内核gc写线程
3. gc->gc_read_ts = kthread_create()  //创建内核gc读线程
4. //设置内核定时器
    setup_timer(&gc->gc_timer, pblk_gc_timer, (unsigned long)pblk);
    mod_timer(&gc-
5.  //gc线程:   检查line的状态（是否写满、是否有脏数据等等），把需要GC的line放到pblk_gc结构体的r_list中  

    //gc读线程: 根据pblk_gc结构体中的r_list对line进行读取，把读到的有效数据存入w_list
    
    // gc写线程: 将w_list的内容写入cache（调用gc用来写cache的函数）也就是写入ring buffer
      
      

* GC搬移时统计相应可用sec的计数，sec的ref越大说明无效的越多，优先选择进行gc

## pblk_gc_run(struct pblk *pblk)
*      没有有效sec的line将立即被释放，或者gc被激活了，有效的block少于阈值，或者是用户空间强制执行的，只有那些无效sectors的ref高的才会执行
        line = pblk_gc_get_victim_line(pblk, group_list);   //   将需要gc的line加入list链表中
        run_gc = pblk_gc_should_run(&pblk->gc, &pblk->rl);   //执行需要gc的rl

## 代码流程如下，从1依次往下调用

1.      pblk_gc_line（）函数调用line_ws = mempool_alloc(pblk->line_ws_pool, GFP_KERNEL);
        创建内存池，存放line_ws(work struct)
        调用INIT_WORK(&line_ws->ws, pblk_gc_line_prepare_ws);

2.      pblk_gc_line_prepare_ws（），/*gc准备工作，调用初始化gc_line_ws函数*/
              ret = pblk_line_read_emeta(pblk, line, emeta_buf);  /*读末尾的元数据，不可用报错*/
              lba_list = pblk_recov_get_lba_list(pblk, emeta_buf);    //如果上面的读失败了，recovery
	      sec_left = pblk_line_vsc(line);                //剩余可用的valid sec count
        调用INIT_WORK(&line_rq_ws->ws, pblk_gc_line_ws);  /**/        

3.       pblk_gc_line_ws()   /*GC工作启动函数，调用pblk_gc_move_valid_secs*/
              pblk_gc_move_valid_secs()();      //移动有用的secs
              mempool_free();    /*内存池空间释放*/
              
4.       pblk_gc_move_valid_secs()            /*搬移有用的secs*/
         调用pblk_submit_read_gc（）          /* Read from GC victim block */
         pblk_gc_writer_kick(&pblk->gc);      /*唤醒GC写线程，wake_up_process(gc->gc_writer_ts);*/
         
## pblk_GC_write()
* 暂时没找到哪里调用，不过这个函数很是很重要的，下面讲解一下流程
        GC要write的内容放在list双向链表里，首先调用list_cut_position(&w_list, &gc->w_list, gc->w_list.prev);   
        //list划分来得到要写的list，对于每一条要写的list，pblk_write_gc_to_cache(）都将这条GC写放到cache中，统一写下去
        list_del(&gc_rq->list);//删除请求的list
        kref_put(&gc_rq->line->ref, pblk_line_put); /* Write buffer L2P references -- */
  
## pblk_gc_read()
*  同样讲解下流程：
        line = list_first_entry(&gc->r_list, struct pblk_line, list);  //首先读取第一条记录
        list_del(&line->list);                                       //从list中删除读取过的记录
        pblk_gc_kick(pblk);                   //调用pblk_gc_writer_kick(gc);
	                                        //pblk_gc_reader_kick(gc);唤醒读写线程
                                                
        pblk_gc_line（）;  //what?  居然是你调用开头的pblk_gc_line();
