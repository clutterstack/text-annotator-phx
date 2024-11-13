export const CtrlEnter = {
    mounted() {
        this.el.focus();
        this.el.setSelectionRange(-1, -1);
        this.el.addEventListener('keydown', (e) => {
            if (e.key === 'Tab') {
                e.preventDefault();
                var start = this.el.selectionStart;
                var end = this.el.selectionEnd;
                console.log(this.el.value);
                var val = this.el.value;
                var selected = val.substring(start, end);
                var re = /^/gm;
                var count = selected.match(re).length;
                this.el.value = val.substring(0, start) + selected.replace(re, '\t') + val.substring(end);
                this.el.selectionStart = start;
                this.el.selectionEnd = end + count;
            }
            if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
                this.el.form.dispatchEvent(new Event('submit', 
                    {bubbles: true, cancelable: true}
                ));
            }
            if (this.el.value == '' && e.key === 'Backspace') {
                const cell = this.el.closest('[role="gridcell"]');
                if (cell.dataset.deletable === "true") {
                    console.log("detected backspace in empty deletable cell; emitting delete_line event");
                    const rowIndex = this.el.dataset.rowIndex;
                    this.pushEvent('delete_line');
                }
            }
        })
      }
}
