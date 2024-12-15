export const CtrlEnter = {
    mounted() {
        textEl = this.el.firstElementChild;
        textEl.focus();
        textEl.setSelectionRange(-1, -1);
        textEl.addEventListener('keydown', (e) => {
            // Using keydown simply because I want to use cmd-enter to
            // submit the form, and when cmd (metaKey) is held down, 
            // MacOs apparently doesn't emit the keyup event
            if (e.key === 'Tab') {
                e.preventDefault();
                var start = textEl.selectionStart;
                var end = textEl.selectionEnd;
                console.log(textEl.value);
                var val = textEl.value;
                var selected = val.substring(start, end);
                var re = /^/gm;
                var count = selected.match(re).length;
                textEl.value = val.substring(0, start) + selected.replace(re, '\t') + val.substring(end);
                textEl.selectionStart = start;
                textEl.selectionEnd = end + count;
            }
            if ((e.metaKey || e.ctrlKey) && e.key == 'Enter') {
                console.log("ctrl-enter detected in js hook; submit changes to line content or note");
                const chunkId = this.el.dataset.chunkId;
                const colName = this.el.dataset.colName;
                this.pushEvent('update_cell', {
                    chunk_id: chunkId,
                    col_name: colName,
                    value: textEl.value
                  });

                // this.el.form.dispatchEvent(new Event('submit', 
                    // {bubbles: true, cancelable: true}
                // ));
            }
            if (textEl.value == '' && e.key === 'Backspace') {
                console.log("backspace on empty textarea");
                const cell = textEl.closest('[role="gridcell"]');
                console.log("closest gricell? " + cell);
                if (cell.dataset.deletable === "true") {
                    console.log("detected backspace in empty deletable cell; emitting delete_line event");
                    const rowIndex = textEl.dataset.rowIndex;
                    this.pushEvent('delete_line');
                }
            }
            if (e.key === 'Escape') {
                console.log("got escape during editing")
                e.preventDefault();
                const cell = this.el.closest('[role="gridcell"]');
                this.pushEvent("cancel_edit");
                cell.focus();
            }
        })
      }
}
