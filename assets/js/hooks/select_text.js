export const SelectText = {

  mounted() {
  document.addEventListener('selectionchange', () => {
      const selection = window.getSelection();
      const range = selection.rangeCount > 0 ? selection.getRangeAt(0) : null;
      // range.commonAncestorContainer is the deepest element that holds both 
      // ends of the range
      if (range && this.el.contains(range.commonAncestorContainer)) {
         console.log("IN SelectTect. is `this.el` a thing?", this.el);
          const selectedText = selection.toString(); //.trim();
          const chunkId = this.el?.id;
          if (selectedText) {
              console.log('Selected text within target:', selectedText);
             this.pushEvent("text_selected", {
              text: selectedText,
              chunk_id: chunkId,
              start_offset: range.startOffset
            });
          }
      }
  });
}


  // mounted() {
  //   document.addEventListener("selectionchange", () => {
  //     let selection = window.getSelection();
  //     let text = selection.toString();
      
  //     if (text && selection && selection.rangeCount > 0) {
  //       console.log("IN SelectTect. is `el` a thing?", this.el);
  //       const range = selection.getRangeAt(0); // we're kind of assuming the whole selection's within one node
  //       const element = selection.anchorNode.parentElement; // the parent element of the text node where the selection started
  //       const chunkId = element?.id;
        
  //       this.pushEvent("text_selected", {
  //         text: text,
  //         chunk_id: chunkId,
  //         start_offset: range.startOffset
  //       });
  //     }
  //   });
  // }

  // mounted() {
  //   document.addEventListener("selectionchange", () => {
  //     let selection = window.getSelection();
  //     let text = selection.toString();
      
  //     if (text && selection && selection.rangeCount > 0) {
  //       const range = selection.getRangeAt(0); // we're kind of assuming the whole selection's within one node
  //       const element = selection.anchorNode.parentElement; // the parent element of the text node where the selection started
  //       const chunkId = element?.id;
        
  //       this.pushEvent("text_selected", {
  //         text: text,
  //         chunk_id: chunkId,
  //         start_offset: range.startOffset
  //       });
  //     }
  //   });
  // }



}