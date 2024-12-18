export const EditKeys = {
    mounted() {
        textEl = this.el.firstElementChild;
        textEl.focus();
        textEl.setSelectionRange(-1, -1);
        textEl.addEventListener('keydown', (e) => {
            // Using keydown simply because MacOs apparently doesn't emit 
            // keyup events when cmd (metaKey) is held down. 
            if (e.key === 'Tab') {
                e.preventDefault();
                var start = textEl.selectionStart;
                var end = textEl.selectionEnd;
                //console.log(textEl.value);
                var val = textEl.value;
                var selected = val.substring(start, end);
                var re = /^/gm;
                var count = selected.match(re).length;
                textEl.value = val.substring(0, start) + selected.replace(re, '\t') + val.substring(end);
                textEl.selectionStart = start;
                textEl.selectionEnd = end + count;
            }
            if ((e.metaKey || e.ctrlKey) && e.key == 'Enter') {
                //console.log("ctrl-enter detected in js hook; submit changes to line content or note");
                const chunkId = this.el.dataset.chunkId;
                const colName = this.el.dataset.colName;
                this.pushEvent('update_cell', {
                    chunk_id: chunkId,
                    col_name: colName,
                    value: textEl.value
                  });
            }
            if (e.key === 'Escape') {
                //console.log("got escape during editing")
                e.preventDefault();
                const cell = this.el.closest('[role="gridcell"]');
                this.pushEvent("cancel_edit");
                cell.focus();
            }
        })
      }
}
