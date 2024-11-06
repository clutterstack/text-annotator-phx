export const CtrlEnter = {
    mounted() {
        this.el.focus();
        this.el.setSelectionRange(-1, -1);
        this.el.addEventListener("keydown", (e) => {
            if (e.key == 'Escape') {
                this.pushEvent("cancel_edit");
                return;
            }
          if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
            
            this.el.form.dispatchEvent(
              new Event('submit', {bubbles: true, cancelable: true}));
          }
        })
      }
}