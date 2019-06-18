#!/usr/bin/env gracket
#lang racket/gui

(require racket/class
         racket/cmdline
         racket/path
         racket/string
         rsvg)

(define folder-path
  (command-line #:args ([path (current-directory)]) path))

(define filenames
  (for/list ([filename (directory-list folder-path)]
             #:when (equal? (path-get-extension filename) #".svg"))
    (path->string filename)))

(define (debounce p #:interval [interval 50])
  (define ch (make-channel))
  (thread
   (lambda _
     (let loop ([events null])
       (sync
        (handle-evt
         (alarm-evt (+ (current-inexact-milliseconds) interval))
         (lambda _
           (cond
             [(null? events)
              (loop events)]

             [(< (- (current-inexact-milliseconds)
                    (send (car events) get-time-stamp)) interval)
              (loop events)]

             [else
              (p (car events))
              (loop null)])))

        (handle-evt
         ch
         (lambda (e)
           (loop (cons e events))))))))

  (lambda (_ e)
    (channel-put ch e)))

(define filter!
  (debounce
   (lambda _
     (define text
       (send search-box get-value))

     (send list-box clear)
     (for ([filename filenames]
           #:when (string-contains? filename text))
       (send list-box append filename)))))

(define (select! tb e)
  (define selection (send tb get-string-selection))
  (define filename (and selection (build-path folder-path selection)))
  (when (eq? (send e get-event-type) 'list-box-dclick)
    (copy-file filename (put-file #f frame #f selection)))

  (when filename
    (define svg (load-svg-from-file filename 3))
    (define dc (send canvas get-dc))

    (define-values (w h)
      (send canvas get-virtual-size))

    (send dc clear)
    (send dc draw-bitmap svg
          ((w . / . 2) . - . ((send svg get-width)  . / . 2))
          ((h . / . 2) . - . ((send svg get-height) . / . 2)))))

(define frame
  (new frame%
       [label "Icon Viewer"]
       [width 1200]
       [height 900]))

(define panel
  (new vertical-panel%
       [parent frame]))

(define search-box
  (new text-field%
       [parent panel]
       [label #f]
       [callback filter!]))

(define list-box
  (new list-box%
       [parent panel]
       [label #f]
       [choices filenames]
       [callback select!]))

(define canvas
  (new canvas%
       [parent panel]))

(send frame show #t)
