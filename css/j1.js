document.addEventListener('DOMContentLoaded', (event) => {
    const events = document.querySelectorAll('.event');

    events.forEach(event => {
        event.addEventListener('dragstart', handleDragStart);
        event.addEventListener('dragover', handleDragOver);
        event.addEventListener('drop', handleDrop);
    });

    let draggedEvent = null;

    function handleDragStart(e) {
        draggedEvent = this;
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/html', this.innerHTML);
    }

    function handleDragOver(e) {
        if (e.preventDefault) {
            e.preventDefault();
        }
        e.dataTransfer.dropEffect = 'move';
        return false;
    }

    function handleDrop(e) {
        if (e.stopPropagation) {
            e.stopPropagation();
        }

        if (draggedEvent !== this) {
            draggedEvent.innerHTML = this.innerHTML;
            this.innerHTML = e.dataTransfer.getData('text/html');
        }

        return false;
    }
});
